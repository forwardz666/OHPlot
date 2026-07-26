
c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so:	file format elf64-littleaarch64

Disassembly of section .text:

0000000000050f7c <_ZN32QOpenHarmonyPlatformInputContext16handleMouseEventERK21OpenHarmonyMouseEvent>:
   50f7c: a9be7bfd     	stp	x29, x30, [sp, #-32]!
   50f80: a9014ff4     	stp	x20, x19, [sp, #16]
   50f84: 910003fd     	mov	x29, sp
   50f88: aa0103f4     	mov	x20, x1
   50f8c: aa0003f3     	mov	x19, x0
   50f90: 97fff0d9     	bl	0x4d2f4 <_ZN27QOpenHarmonyJsWindowManager8instanceEv>
   50f94: f9400281     	ldr	x1, [x20]
   50f98: 97fff104     	bl	0x4d3a8 <_ZNK27QOpenHarmonyJsWindowManager6windowEP19OH_NativeXComponent>
   50f9c: b40001c0     	cbz	x0, 0x50fd4 <_ZN32QOpenHarmonyPlatformInputContext16handleMouseEventERK21OpenHarmonyMouseEvent+0x58>
   50fa0: b9401288     	ldr	w8, [x20, #16]
   50fa4: aa0003e1     	mov	x1, x0
   50fa8: 7100091f     	cmp	w8, #2
   50fac: 540001a0     	b.eq	0x50fe0 <_ZN32QOpenHarmonyPlatformInputContext16handleMouseEventERK21OpenHarmonyMouseEvent+0x64>
   50fb0: 71000d1f     	cmp	w8, #3
   50fb4: 54000200     	b.eq	0x50ff4 <_ZN32QOpenHarmonyPlatformInputContext16handleMouseEventERK21OpenHarmonyMouseEvent+0x78>
   50fb8: 7100151f     	cmp	w8, #5
   50fbc: 54000241     	b.ne	0x51004 <_ZN32QOpenHarmonyPlatformInputContext16handleMouseEventERK21OpenHarmonyMouseEvent+0x88>
   50fc0: 2d410680     	ldp	s0, s1, [x20, #8]
   50fc4: b9401682     	ldr	w2, [x20, #20]
   50fc8: aa1303e0     	mov	x0, x19
   50fcc: 94000012     	bl	0x51014 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE>
   50fd0: 1400000d     	b	0x51004 <_ZN32QOpenHarmonyPlatformInputContext16handleMouseEventERK21OpenHarmonyMouseEvent+0x88>
   50fd4: a9414ff4     	ldp	x20, x19, [sp, #16]
   50fd8: a8c27bfd     	ldp	x29, x30, [sp], #32
   50fdc: d65f03c0     	ret
   50fe0: 2d410680     	ldp	s0, s1, [x20, #8]
   50fe4: b9401682     	ldr	w2, [x20, #20]
   50fe8: aa1303e0     	mov	x0, x19
   50fec: 9400005b     	bl	0x51158 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE>
   50ff0: 14000005     	b	0x51004 <_ZN32QOpenHarmonyPlatformInputContext16handleMouseEventERK21OpenHarmonyMouseEvent+0x88>
   50ff4: 2d410680     	ldp	s0, s1, [x20, #8]
   50ff8: b9401682     	ldr	w2, [x20, #20]
   50ffc: aa1303e0     	mov	x0, x19
   51000: 940000b1     	bl	0x512c4 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE>
   51004: a9414ff4     	ldp	x20, x19, [sp, #16]
   51008: aa1f03e0     	mov	x0, xzr
   5100c: a8c27bfd     	ldp	x29, x30, [sp], #32
   51010: 1402ae30     	b	0xfc8d0 <_ZN22QWindowSystemInterface23flushWindowSystemEventsE6QFlagsIN10QEventLoop17ProcessEventsFlagEE@plt>

c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so:	file format elf64-littleaarch64

Disassembly of section .text:

0000000000050f78 <_ZN32QOpenHarmonyPlatformInputContext9touchDownEff>:
   50f78: d65f03c0     	ret
