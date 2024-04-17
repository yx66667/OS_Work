#ifndef __KERN_MM_VMM_H__
#define __KERN_MM_VMM_H__

#include <defs.h>
#include <list.h>
#include <memlayout.h>
#include <sync.h>

//pre define
struct mm_struct;

// the virtual continuous memory area(vma)
struct vma_struct {
    // 指向mm表头
    struct mm_struct *vm_mm; // the set of vma using the same PDT 
    // 描述的虚拟内存的起始地址
    uintptr_t vm_start;      //    start addr of vma    
    // 描述的虚拟内存的截止地址
    uintptr_t vm_end;        // end addr of vma
    // 当前虚拟内存块的属性flags
    // bit0 VM_READ标识是否可读; bit1 VM_WRITE标识是否可写; bit2 VM_EXEC标识是否可执行
    uint32_t vm_flags;       // flags of vma
    // 连续虚拟内存块链表节点。虚拟内存块的起始位置串起来的链表
    list_entry_t list_link;  // linear list link which sorted by start addr of vma
};

#define le2vma(le, member)                  \
    to_struct((le), struct vma_struct, member)

#define VM_READ                 0x00000001
#define VM_WRITE                0x00000002
#define VM_EXEC                 0x00000004

// the control struct for a set of vma using the same PDT
struct mm_struct {
    // 连续虚拟内存块链表 (不能出现重叠)
    list_entry_t mmap_list;        // linear list link which sorted by start addr of vma
    // 当前访问的mmap_list链表中的vma块(由于局部性原理，之前访问过的vma有更大可能会在后续继续访问，该缓存可以减少从mmap_list中进行遍历查找的次数，提高效率)
    struct vma_struct *mmap_cache; // current accessed vma, used for speed purpose
    // 当前mm_struct关联的一级页表的指针
    pde_t *pgdir;                  // the PDT of these vma
    // 当前mm_struct->mmap_list中vma块的数量
    int map_count;                 // the count of these vma
    // 将其做为了一个先进先出链表队列
    void *sm_priv;                   // the private data for swap manager
};

struct vma_struct *find_vma(struct mm_struct *mm, uintptr_t addr);
struct vma_struct *vma_create(uintptr_t vm_start, uintptr_t vm_end, uint32_t vm_flags);
void insert_vma_struct(struct mm_struct *mm, struct vma_struct *vma);

struct mm_struct *mm_create(void);
void mm_destroy(struct mm_struct *mm);

void vmm_init(void);

int do_pgfault(struct mm_struct *mm, uint32_t error_code, uintptr_t addr);

extern volatile unsigned int pgfault_num;
extern struct mm_struct *check_mm_struct;
#endif /* !__KERN_MM_VMM_H__ */

