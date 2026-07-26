
c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so:	file format elf64-littleaarch64

Disassembly of section .text:

000000000004c220 <_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv>:
   4c220: d103c3ff     	sub	sp, sp, #240
   4c224: a90d7bfd     	stp	x29, x30, [sp, #208]
   4c228: 910343fd     	add	x29, sp, #208
   4c22c: a90e4ff4     	stp	x20, x19, [sp, #224]
   4c230: aa0103f4     	mov	x20, x1
   4c234: aa0003f3     	mov	x19, x0
   4c238: 94001b12     	bl	0x52e80 <_ZN32QOpenHarmonyPlatformInputContext23openHarmonyInputContextEv>
   4c23c: b40005e0     	cbz	x0, 0x4c2f8 <_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv+0xd8>
   4c240: d10083a2     	sub	x2, x29, #32
   4c244: aa1303e0     	mov	x0, x19
   4c248: aa1403e1     	mov	x1, x20
   4c24c: 9402c471     	bl	0xfd410 <OH_NativeXComponent_GetMouseEvent@plt>
   4c250: 35000540     	cbnz	w0, 0x4c2f8 <_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv+0xd8>
   4c254: 297f2ba8     	ldp	w8, w10, [x29, #-8]
   4c258: 2a1f03e9     	mov	w9, wzr
   4c25c: 5100054b     	sub	w11, w10, #1
   4c260: 71003d7f     	cmp	w11, #15
   4c264: 54000108     	b.hi	0x4c284 <_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv+0x64>
   4c268: d503201f     	nop
   4c26c: 10f070ac     	adr	x12, #-127468
   4c270: 1000008d     	adr	x13, #16
   4c274: 386b698e     	ldrb	w14, [x12, x11]
   4c278: 8b0e09ad     	add	x13, x13, x14, lsl #2
   4c27c: d61f01a0     	br	x13
   4c280: 2a0a03e9     	mov	w9, w10
   4c284: fc5e83a0     	ldur	d0, [x29, #-24]
   4c288: 51000508     	sub	w8, w8, #1
   4c28c: 7100091f     	cmp	w8, #2
   4c290: f81c83b3     	stur	x19, [x29, #-56]
   4c294: b81dc3a9     	stur	w9, [x29, #-36]
   4c298: fc1d03a0     	stur	d0, [x29, #-48]
   4c29c: 540000a8     	b.hi	0x4c2b0 <_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv+0x90>
   4c2a0: b0ffff09     	adrp	x9, 0x2d000 <_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv+0x4>
   4c2a4: 9102b129     	add	x9, x9, #172
   4c2a8: b868d928     	ldr	w8, [x9, w8, sxtw #2]
   4c2ac: 14000002     	b	0x4c2b4 <_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv+0x94>
   4c2b0: 2a1f03e8     	mov	w8, wzr
   4c2b4: b81d83a8     	stur	w8, [x29, #-40]
   4c2b8: 94001af2     	bl	0x52e80 <_ZN32QOpenHarmonyPlatformInputContext23openHarmonyInputContextEv>
   4c2bc: 6f00e400     	movi	v0.2d, #0000000000000000
   4c2c0: f0fffec6     	adrp	x6, 0x27000 <_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv+0xc>
   4c2c4: 910754c6     	add	x6, x6, #469
   4c2c8: aa1f03e3     	mov	x3, xzr
   4c2cc: aa1f03e4     	mov	x4, xzr
   4c2d0: f0fffec1     	adrp	x1, 0x27000 <_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv+0x1c>
   4c2d4: 9120a821     	add	x1, x1, #2090
   4c2d8: d100e3a5     	sub	x5, x29, #56
   4c2dc: 52800042     	mov	w2, #2
   4c2e0: ad0083e0     	stp	q0, q0, [sp, #16]
   4c2e4: ad0183e0     	stp	q0, q0, [sp, #48]
   4c2e8: ad0283e0     	stp	q0, q0, [sp, #80]
   4c2ec: ad0383e0     	stp	q0, q0, [sp, #112]
   4c2f0: 3d8003e0     	str	q0, [sp]
   4c2f4: 9402c21f     	bl	0xfcb70 <_ZN11QMetaObject12invokeMethodEP7QObjectPKcN2Qt14ConnectionTypeE22QGenericReturnArgument16QGenericArgumentS7_S7_S7_S7_S7_S7_S7_S7_S7_@plt>
   4c2f8: a94e4ff4     	ldp	x20, x19, [sp, #224]
   4c2fc: a94d7bfd     	ldp	x29, x30, [sp, #208]
   4c300: 9103c3ff     	add	sp, sp, #240
   4c304: d65f03c0     	ret
