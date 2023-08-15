#define BF_LBRACE	91
#define BF_RBRACE	93

#define BF_DOT	46
#define BF_COMMA	44

#define BF_PLUS	43
#define BF_MINUS	45

#define BF_LSHIFT	60
#define BF_RSHIFT	62

	.global	_start
	.text
_start:
	/* All incoming registers at zero.  */

	/* read 32768 bytes.  */
	movb	$0x80, %dh
	leal	(G_mem + 65536)(%rip), %esi
	/* eax/edi are already zero which happens to match
	   SYS_read/STDIN_FILENO.  */
	syscall


	/* Stack of braces grows down from below the program code.  */
	movl	%esi, %esp
	/* Program code grows up.  */
	movl	%esi, %ecx
	/* Assuming no errors, reach stores size in eax. Note errors or
	   0-byte reads are okay. The ecx is readable memory and zero-
	   initialized (bss), so it its zero-length, it will just be an
	   invalid op and we will hit bounds check below. If its error,
	   eax is negative so ebp will be negative and likewise we will
	   hit bounds check below.  */
	leal	(%rcx, %rax), %ebp
	/* Adjust esi + 32768 (max number of cells/program size).  */
	addl	%edx, %esi
	/* We have 32768 in edx, so get 1 in it (we need that in alot of
	   places).  */
	shrl	$15, %edx
run_program:
	movzbl	(%rcx), %eax
	incl	%ecx
	/* %al contains the program "instruction". Its unique to one of
	   8 values so just test each in order. If instruction matches
	   execute it then fallthrough (%al can only ever match one).
	   We occasionally set al but are sure never to set it to the
	   ASCII value of any of our 8 instructions.  */

	/* TODO: Brace handling could probably be smaller.  */
try_lbrace:
	cmpb	$BF_LBRACE, %al
	jne	try_rbrace
	/* Cur current insn on the stack.  */
	push	%rcx
	/* Push skip state on the stack.  */
	push	%rbx
	/* If cell is zero, then we are skipping till RBRACE. Note we
	   have 1 cached in edx.  */
	cmpb	%dl, (%rsi)
	/* Each match BF_LBRACE, so rest will never match if we or it in.  */
	cmovb	%eax, %ebx
	/* Push.  */

try_rbrace:
	cmpb	$BF_RBRACE, %al
	jne	try_cont
	/* Popping state (we might repush if we are looping back).  */
	pop	%rbx
	pop	%rdi
	/* Non-zero cell means loop. Note we have 1 cached in edx.  */
	cmpb	%dl, (%rsi)
	jb	next_insn
	/* Restore loop state.  */
	movl	%edi, %ecx
	push	%rcx
	push	%rbx
try_cont:
	/* we have set ebx s.t its either zero or has a value that makes
	   any further matches impossible.  */
	orb	%bl, %al

	/* For the rest of the ops we take advantage of the fact that
	   the ascii values of the pairs '<'/'>', '+'/'-', and '.',','
	   are all 2 apart. This allows use to test a pair with the
	   following formula: `((al - PAIR_LO) & -3) == 0`. This will
	   always leave the pair as 0/2 and will match only the pair.
	   It turns out 0/2 are useful and can be used to do all the
	   rest of the operations w.o extra branches.  */

try_lshift:
	subb	$BF_LSHIFT, %al
	testb	$-3, %al
	jnz	try_minus
	addl	%eax, %esi
	decl	%esi

try_minus:
try_plus:
	subb	$(BF_PLUS - BF_LSHIFT), %al
	testb	$-3, %al
	/* '.'/',' are '+'/'-' + 1 respectively, so since %al is off by
	   1 anyways we can share codes using `lea`.  */
	leal	-1(%rax), %eax
	jnz	try_comma
	subb	%al, (%rsi)

try_comma:
try_dot:
	testb	$-3, %al
	jnz	next_insn
do_syscall:
	/* rcx is clobbered by syscall. There is probably a refactor so
	   we can save a register elsewhere so we don't need to
	   save/restore rcx, but I can't find it.  */
	push	%rcx
	/* al is either 2/0. Shift by 1 to get 1/0 for our syscall number.  */
	shrb	$1, %al
	/* SYS_write == STDOUT_FILENO, SYS_read == STDIN_FILENO.  */
	movl	%eax, %edi
	/* We already have 1 in rdx.  */
	syscall
	pop	%rcx

next_insn:
	cmpl	%ecx, %ebp
	jg	run_program

	/* eax has zero upper 24 bits so we can cheat and use movb here.
	   (This isn't exact correct, assuming no IO errors on last
	   instruction).  */
	movb	$60, %al
	syscall

	.section .bss
	.align	65536
G_mem:	.space(65536 * 2)
