#define REALLOC(x) (x - KERNBASE)
#这里是内核的代码段，被加载在物理地址的1mB的位置
.text
.globl kern_entry
kern_entry:

    # 初始化内核环境的页表,把页目录表地址重定位后放入cr3
    #页目录表分析在下面
    movl $REALLOC(__boot_pgdir), %eax
    movl %eax, %cr3

    # 使能 paging.
    movl %cr0, %eax
    orl $(CR0_PE | CR0_PG | CR0_AM | CR0_WP | CR0_NE | CR0_TS | CR0_EM | CR0_MP), %eax
    andl $~(CR0_TS | CR0_EM), %eax
    movl %eax, %cr0

    # 现在我们要更新eip寄存器，现在的eip = 0x1.....
    # mind here！（注意这里）
    #为什么我们要更新eip寄存器？以及为何我们需要一个暂时的（0-4m）:（0-4m）的地址映射？
    #因为我们刚刚开启了分页，这时候要寻址的话，eip寄存器里面应该存的是虚拟地址，但问题是现在ip寄存器里面存的还是我们开启分页以前的物理地址，如果我们直接使用(kernbase,kernbase+4m）:（0-4m）的地址映射的话就会找不到地方，所以我们现在需要一个（0-4m）:（0-4m）的映射来在我们更新eip寄存器（把正确的虚拟地址放到eip寄存器里面替换现在的物理地址）完成之前还能让程序找到地方。
    
    # 执行下面这条指令时,虽然访问的仍然是处于[0,4MB)的物理空间（kernelbase开始的虚拟地址）,因为开启了分页了,会经过页表的查找.将虚拟地址映射到物理地址
    # 为了更新 eip
    # 将next的地址存入eax，存入的next是虚拟地址，jmp之后eip里面也就是虚拟地址了
    leal next, %eax
    # set eip = KERNBASE + 0x1.....
    jmp *%eax
next:
    # jmp 过来之后，eip也就成功的从物理地址切换到虚拟地址了。所以我们现在不需要（0-4m）:（0-4m）的映射了
    # 在这里取消虚拟地址 0 ~ 4M 的映射,即将 __boot_pgdir 置零.
    xorl %eax, %eax
    movl %eax, __boot_pgdir

    # set ebp, esp，搭建栈（ss在之前已经设定好了）
    movl $0x0, %ebp

    # 内核栈范围是 [bootstack, bootstacktop)
    # 内核栈大小是 KSTACKSIZE (8KB), 在memlayout.h 中定义.
    movl $bootstacktop, %esp

    # 内核栈就绪, 调用C 函数
    call kern_init

# should never get here
spin:
    jmp spin

#这里是数据段
.data
.align PGSIZE
    .globl bootstack
bootstack:
    .space KSTACKSIZE
    .globl bootstacktop
bootstacktop:


# 内核内置一级页表.
# 每个一级页表对应 1024 个二级页表,即一个一级页表（页目录）对应4MB的内存
# 我们只需要映射两块,把对虚拟内存 [0,4M)和[KERNBASE, KERNBASE+4M)都映射到物理内存[0,4M)上.
# 所以只需 2 个一级页表项.
# 第一个页表项的上限是KERNBASE,共占用 768 个 entry,共 3072Byte<PAGESIZE,加上第二个页表项,再加上对齐,也没超过1 个 PAGESIZE.
# 而一个 PAGESIZE 可以容纳 4K/4=1K 个 entry. KERNBASE 大概在其中 3/4 的位置,还可以容纳 1K - 768 = 256 个 entry,即 1G 的容量.
# 实际 nm 输出
# c0158000 d __boot_pt1
# c0157c00 d __second_PDE
# c0157000 D __boot_pgdir
# 也可以得到验证, 一级页表共占用 0x1000Byte=4KB


.section .data.pgdir
.align PGSIZE
__boot_pgdir:
.globl __boot_pgdir
    # 第一个一级页表项,把虚拟地址 0 ~ 4M 临时映射到 0 ~ 4M. 在跳到 kern_init 之前就已抹除.
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    # 从 0 到KERNBASE,中间间隔了 KERNBASE/4M = 3072/4=768 项,共 768*4B = 3072Byte,不到一个 PAGESIZE.
    # 为何最后还要<<2 ?每个页表项占用 1 个long,是 32bit,从 byte 到 long 需要*4,即<<2
    .space (KERNBASE >> PGSHIFT >> 10 << 2) - (. - __boot_pgdir) # 与 KERNBASE 的一级页表项对齐
__second_PDE:
    # 第二个一级页表项,把虚拟地址 KERNBASE + (0 ~ 4M) 映射到物理地址 0 ~ 4M
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    .space PGSIZE - (. - __boot_pgdir) # 与 PAGESIZE 对齐.

# ↓ 两个一级页表项都指向下边的二级页表项

# boot 阶段临时单个二级页表内容,专门用于映射至 [0,4MB)
# 定义: 一个二级页表 1024 项,即按 1K 再次分页
# 每项的内容: 从 0 开始,每项的值递增 4096,即 i * PGSIZE,辅以属性
.set i, 0
__boot_pt1:
.globl __boot_pt1
.rept 1024
    .long i * PGSIZE + (PTE_P | PTE_W)
    .set i, i + 1
.endr
