
c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so:	file format elf64-littleaarch64

Disassembly of section .text:

0000000000051158 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE>:
   51158: d10183ff     	sub	sp, sp, #96
   5115c: a9037bfd     	stp	x29, x30, [sp, #48]
   51160: 9100c3fd     	add	x29, sp, #48
   51164: a90457f6     	stp	x22, x21, [sp, #64]
   51168: a9054ff4     	stp	x20, x19, [sp, #80]
   5116c: b4000a21     	cbz	x1, 0x512b0 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x158>
   51170: aa0003f4     	mov	x20, x0
   51174: 3940e008     	ldrb	w8, [x0, #56]
   51178: 350009c8     	cbnz	w8, 0x512b0 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x158>
   5117c: 1e380008     	fcvtzs	w8, s0
   51180: 1e380029     	fcvtzs	w9, s1
   51184: aa0103e0     	mov	x0, x1
   51188: 2a0203f3     	mov	w19, w2
   5118c: 293f27a8     	stp	w8, w9, [x29, #-8]
   51190: 94003243     	bl	0x5da9c <_ZNK20QOpenHarmonyJsWindow8qtWindowEv>
   51194: aa0003f5     	mov	x21, x0
   51198: b4000060     	cbz	x0, 0x511a4 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x4c>
   5119c: aa1503e0     	mov	x0, x21
   511a0: 9402ad20     	bl	0xfc620 <_ZN15QtSharedPointer20ExternalRefCountData9getAndRefEPK7QObject@plt>
   511a4: f9403288     	ldr	x8, [x20, #96]
   511a8: a9065680     	stp	x0, x21, [x20, #96]
   511ac: b4000128     	cbz	x8, 0x511d0 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x78>
   511b0: 885ffd09     	ldaxr	w9, [x8]
   511b4: 71000529     	subs	w9, w9, #1
   511b8: 880afd09     	stlxr	w10, w9, [x8]
   511bc: 35ffffaa     	cbnz	w10, 0x511b0 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x58>
   511c0: 54000061     	b.ne	0x511cc <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x74>
   511c4: aa0803e0     	mov	x0, x8
   511c8: 9402acf2     	bl	0xfc590 <_ZdlPv@plt>
   511cc: f9403280     	ldr	x0, [x20, #96]
   511d0: b40001e0     	cbz	x0, 0x5120c <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xb4>
   511d4: b9400408     	ldr	w8, [x0, #4]
   511d8: 340001a8     	cbz	w8, 0x5120c <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xb4>
   511dc: f9403688     	ldr	x8, [x20, #104]
   511e0: b4000168     	cbz	x8, 0x5120c <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xb4>
   511e4: b940041f     	ldr	wzr, [x0, #4]
   511e8: d10023a1     	sub	x1, x29, #8
   511ec: aa0803e0     	mov	x0, x8
   511f0: 9402b144     	bl	0xfd700 <_ZNK7QWindow13mapFromGlobalERK6QPoint@plt>
   511f4: aa0003e8     	mov	x8, x0
   511f8: f9403280     	ldr	x0, [x20, #96]
   511fc: d360fd09     	lsr	x9, x8, #32
   51200: b50000c0     	cbnz	x0, 0x51218 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xc0>
   51204: aa1f03f5     	mov	x21, xzr
   51208: 14000008     	b	0x51228 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xd0>
   5120c: f85f83a8     	ldur	x8, [x29, #-8]
   51210: d360fd09     	lsr	x9, x8, #32
   51214: b4ffff80     	cbz	x0, 0x51204 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xac>
   51218: b940040a     	ldr	w10, [x0, #4]
   5121c: f940368b     	ldr	x11, [x20, #104]
   51220: 7100015f     	cmp	w10, #0
   51224: 9a8b03f5     	csel	x21, xzr, x11, eq
   51228: fc5f83a0     	ldur	d0, [x29, #-8]
   5122c: 1e620101     	scvtf	d1, w8
   51230: f9401a96     	ldr	x22, [x20, #48]
   51234: 1e620122     	scvtf	d2, w9
   51238: 0f20a400     	sshll	v0.2d, v0.2s, #0
   5123c: b94022c8     	ldr	w8, [x22, #32]
   51240: 4e61d800     	scvtf	v0.2d, v0.2d
   51244: 6d018be1     	stp	d1, d2, [sp, #24]
   51248: 3d8003e0     	str	q0, [sp]
   5124c: 34000108     	cbz	w8, 0x5126c <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x114>
   51250: f94006c9     	ldr	x9, [x22, #8]
   51254: f9400120     	ldr	x0, [x9]
   51258: eb16001f     	cmp	x0, x22
   5125c: 540000c1     	b.ne	0x51274 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x11c>
   51260: 71000508     	subs	w8, w8, #1
   51264: 91002129     	add	x9, x9, #8
   51268: 54ffff61     	b.ne	0x51254 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xfc>
   5126c: aa1f03f4     	mov	x20, xzr
   51270: 14000007     	b	0x5128c <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x134>
   51274: 2a1f03f4     	mov	w20, wzr
   51278: b9400c08     	ldr	w8, [x0, #12]
   5127c: 2a140114     	orr	w20, w8, w20
   51280: 9402b104     	bl	0xfd690 <_ZN9QHashData8nextNodeEPNS_4NodeE@plt>
   51284: eb16001f     	cmp	x0, x22
   51288: 54ffff81     	b.ne	0x51278 <_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x120>
   5128c: 2a1303e3     	mov	w3, w19
   51290: 910063e1     	add	x1, sp, #24
   51294: 910003e2     	mov	x2, sp
   51298: aa1503e0     	mov	x0, x21
   5129c: 2a1303e4     	mov	w4, w19
   512a0: 52800045     	mov	w5, #2
   512a4: aa1403e6     	mov	x6, x20
   512a8: 2a1f03e7     	mov	w7, wzr
   512ac: 9402b119     	bl	0xfd710 <_ZN22QWindowSystemInterface16handleMouseEventINS_15DefaultDeliveryEEEbP7QWindowRK7QPointFS6_6QFlagsIN2Qt11MouseButtonEES9_N6QEvent4TypeES7_INS8_16KeyboardModifierEENS8_16MouseEventSourceE@plt>
   512b0: a9454ff4     	ldp	x20, x19, [sp, #80]
   512b4: a94457f6     	ldp	x22, x21, [sp, #64]
   512b8: a9437bfd     	ldp	x29, x30, [sp, #48]
   512bc: 910183ff     	add	sp, sp, #96
   512c0: d65f03c0     	ret

c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so:	file format elf64-littleaarch64

Disassembly of section .text:

00000000000512c4 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE>:
   512c4: d10183ff     	sub	sp, sp, #96
   512c8: a9027bfd     	stp	x29, x30, [sp, #32]
   512cc: 910083fd     	add	x29, sp, #32
   512d0: f9001bf7     	str	x23, [sp, #48]
   512d4: a90457f6     	stp	x22, x21, [sp, #64]
   512d8: a9054ff4     	stp	x20, x19, [sp, #80]
   512dc: b40008c1     	cbz	x1, 0x513f4 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x130>
   512e0: aa0003f5     	mov	x21, x0
   512e4: 3940e008     	ldrb	w8, [x0, #56]
   512e8: 35000868     	cbnz	w8, 0x513f4 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x130>
   512ec: aa1503f6     	mov	x22, x21
   512f0: 2a0203f3     	mov	w19, w2
   512f4: 1e380009     	fcvtzs	w9, s0
   512f8: 1e38002a     	fcvtzs	w10, s1
   512fc: f8460ec8     	ldr	x8, [x22, #96]!
   51300: 29032ba9     	stp	w9, w10, [x29, #24]
   51304: b40000a8     	cbz	x8, 0x51318 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x54>
   51308: b9400508     	ldr	w8, [x8, #4]
   5130c: 34000068     	cbz	w8, 0x51318 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x54>
   51310: f94036b4     	ldr	x20, [x21, #104]
   51314: b50000b4     	cbnz	x20, 0x51328 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x64>
   51318: aa0103e0     	mov	x0, x1
   5131c: 940031e0     	bl	0x5da9c <_ZNK20QOpenHarmonyJsWindow8qtWindowEv>
   51320: aa0003f4     	mov	x20, x0
   51324: b40000e0     	cbz	x0, 0x51340 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x7c>
   51328: 910063a1     	add	x1, x29, #24
   5132c: aa1403e0     	mov	x0, x20
   51330: 9402b0f4     	bl	0xfd700 <_ZNK7QWindow13mapFromGlobalERK6QPoint@plt>
   51334: 294327a8     	ldp	w8, w9, [x29, #24]
   51338: d360fc0a     	lsr	x10, x0, #32
   5133c: 14000004     	b	0x5134c <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x88>
   51340: 29432ba0     	ldp	w0, w10, [x29, #24]
   51344: 2a0a03e9     	mov	w9, w10
   51348: 2a0003e8     	mov	w8, w0
   5134c: f9401ab7     	ldr	x23, [x21, #48]
   51350: 1e620000     	scvtf	d0, w0
   51354: 1e620141     	scvtf	d1, w10
   51358: 1e620102     	scvtf	d2, w8
   5135c: 1e620123     	scvtf	d3, w9
   51360: b94022e8     	ldr	w8, [x23, #32]
   51364: 6d0107e0     	stp	d0, d1, [sp, #16]
   51368: 6d000fe2     	stp	d2, d3, [sp]
   5136c: 34000108     	cbz	w8, 0x5138c <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xc8>
   51370: f94006e9     	ldr	x9, [x23, #8]
   51374: f9400120     	ldr	x0, [x9]
   51378: eb17001f     	cmp	x0, x23
   5137c: 540000c1     	b.ne	0x51394 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xd0>
   51380: 71000508     	subs	w8, w8, #1
   51384: 91002129     	add	x9, x9, #8
   51388: 54ffff61     	b.ne	0x51374 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xb0>
   5138c: aa1f03f5     	mov	x21, xzr
   51390: 14000007     	b	0x513ac <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xe8>
   51394: 2a1f03f5     	mov	w21, wzr
   51398: b9400c08     	ldr	w8, [x0, #12]
   5139c: 2a150115     	orr	w21, w8, w21
   513a0: 9402b0bc     	bl	0xfd690 <_ZN9QHashData8nextNodeEPNS_4NodeE@plt>
   513a4: eb17001f     	cmp	x0, x23
   513a8: 54ffff81     	b.ne	0x51398 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xd4>
   513ac: 910043e1     	add	x1, sp, #16
   513b0: 910003e2     	mov	x2, sp
   513b4: aa1403e0     	mov	x0, x20
   513b8: aa1f03e3     	mov	x3, xzr
   513bc: 2a1303e4     	mov	w4, w19
   513c0: 52800065     	mov	w5, #3
   513c4: aa1503e6     	mov	x6, x21
   513c8: 2a1f03e7     	mov	w7, wzr
   513cc: 9402b0d1     	bl	0xfd710 <_ZN22QWindowSystemInterface16handleMouseEventINS_15DefaultDeliveryEEEbP7QWindowRK7QPointFS6_6QFlagsIN2Qt11MouseButtonEES9_N6QEvent4TypeES7_INS8_16KeyboardModifierEENS8_16MouseEventSourceE@plt>
   513d0: f94002c0     	ldr	x0, [x22]
   513d4: a9007edf     	stp	xzr, xzr, [x22]
   513d8: b40000e0     	cbz	x0, 0x513f4 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x130>
   513dc: 885ffc08     	ldaxr	w8, [x0]
   513e0: 71000508     	subs	w8, w8, #1
   513e4: 8809fc08     	stlxr	w9, w8, [x0]
   513e8: 35ffffa9     	cbnz	w9, 0x513dc <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x118>
   513ec: 54000041     	b.ne	0x513f4 <_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x130>
   513f0: 9402ac68     	bl	0xfc590 <_ZdlPv@plt>
   513f4: a9454ff4     	ldp	x20, x19, [sp, #80]
   513f8: a94457f6     	ldp	x22, x21, [sp, #64]
   513fc: a9427bfd     	ldp	x29, x30, [sp, #32]
   51400: f9401bf7     	ldr	x23, [sp, #48]
   51404: 910183ff     	add	sp, sp, #96
   51408: d65f03c0     	ret

c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so:	file format elf64-littleaarch64

Disassembly of section .text:

0000000000051014 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE>:
   51014: d10183ff     	sub	sp, sp, #96
   51018: a9027bfd     	stp	x29, x30, [sp, #32]
   5101c: 910083fd     	add	x29, sp, #32
   51020: f9001bf7     	str	x23, [sp, #48]
   51024: a90457f6     	stp	x22, x21, [sp, #64]
   51028: a9054ff4     	stp	x20, x19, [sp, #80]
   5102c: b40008a1     	cbz	x1, 0x51140 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x12c>
   51030: aa0003f5     	mov	x21, x0
   51034: 3940e008     	ldrb	w8, [x0, #56]
   51038: 35000848     	cbnz	w8, 0x51140 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x12c>
   5103c: 2a0203f3     	mov	w19, w2
   51040: 1e380009     	fcvtzs	w9, s0
   51044: 1e38002a     	fcvtzs	w10, s1
   51048: f94032a8     	ldr	x8, [x21, #96]
   5104c: 29032ba9     	stp	w9, w10, [x29, #24]
   51050: b40000a8     	cbz	x8, 0x51064 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x50>
   51054: b9400508     	ldr	w8, [x8, #4]
   51058: 34000068     	cbz	w8, 0x51064 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x50>
   5105c: f94036b4     	ldr	x20, [x21, #104]
   51060: b50000b4     	cbnz	x20, 0x51074 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x60>
   51064: aa0103e0     	mov	x0, x1
   51068: 9400328d     	bl	0x5da9c <_ZNK20QOpenHarmonyJsWindow8qtWindowEv>
   5106c: aa0003f4     	mov	x20, x0
   51070: b40000e0     	cbz	x0, 0x5108c <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x78>
   51074: 910063a1     	add	x1, x29, #24
   51078: aa1403e0     	mov	x0, x20
   5107c: 9402b1a1     	bl	0xfd700 <_ZNK7QWindow13mapFromGlobalERK6QPoint@plt>
   51080: 294327aa     	ldp	w10, w9, [x29, #24]
   51084: d360fc08     	lsr	x8, x0, #32
   51088: 14000004     	b	0x51098 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x84>
   5108c: 294323a0     	ldp	w0, w8, [x29, #24]
   51090: 2a0803e9     	mov	w9, w8
   51094: 2a0003ea     	mov	w10, w0
   51098: 1e620000     	scvtf	d0, w0
   5109c: 1e620101     	scvtf	d1, w8
   510a0: 1e620142     	scvtf	d2, w10
   510a4: 1e620123     	scvtf	d3, w9
   510a8: f94032a8     	ldr	x8, [x21, #96]
   510ac: 6d0107e0     	stp	d0, d1, [sp, #16]
   510b0: 6d000fe2     	stp	d2, d3, [sp]
   510b4: b40000e8     	cbz	x8, 0x510d0 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xbc>
   510b8: b9400508     	ldr	w8, [x8, #4]
   510bc: 340000a8     	cbz	w8, 0x510d0 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xbc>
   510c0: f94036a8     	ldr	x8, [x21, #104]
   510c4: f100011f     	cmp	x8, #0
   510c8: 1a9f07f6     	cset	w22, ne
   510cc: 14000002     	b	0x510d4 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xc0>
   510d0: aa1f03f6     	mov	x22, xzr
   510d4: f9401ab7     	ldr	x23, [x21, #48]
   510d8: b94022e8     	ldr	w8, [x23, #32]
   510dc: 34000108     	cbz	w8, 0x510fc <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xe8>
   510e0: f94006e9     	ldr	x9, [x23, #8]
   510e4: f9400120     	ldr	x0, [x9]
   510e8: eb17001f     	cmp	x0, x23
   510ec: 540000c1     	b.ne	0x51104 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xf0>
   510f0: 71000508     	subs	w8, w8, #1
   510f4: 91002129     	add	x9, x9, #8
   510f8: 54ffff61     	b.ne	0x510e4 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xd0>
   510fc: aa1f03f5     	mov	x21, xzr
   51100: 14000007     	b	0x5111c <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0x108>
   51104: 2a1f03f5     	mov	w21, wzr
   51108: b9400c08     	ldr	w8, [x0, #12]
   5110c: 2a150115     	orr	w21, w8, w21
   51110: 9402b160     	bl	0xfd690 <_ZN9QHashData8nextNodeEPNS_4NodeE@plt>
   51114: eb17001f     	cmp	x0, x23
   51118: 54ffff81     	b.ne	0x51108 <_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE+0xf4>
   5111c: 910043e1     	add	x1, sp, #16
   51120: 910003e2     	mov	x2, sp
   51124: aa1403e0     	mov	x0, x20
   51128: aa1603e3     	mov	x3, x22
   5112c: 2a1303e4     	mov	w4, w19
   51130: 528000a5     	mov	w5, #5
   51134: aa1503e6     	mov	x6, x21
   51138: 2a1f03e7     	mov	w7, wzr
   5113c: 9402b175     	bl	0xfd710 <_ZN22QWindowSystemInterface16handleMouseEventINS_15DefaultDeliveryEEEbP7QWindowRK7QPointFS6_6QFlagsIN2Qt11MouseButtonEES9_N6QEvent4TypeES7_INS8_16KeyboardModifierEENS8_16MouseEventSourceE@plt>
   51140: a9454ff4     	ldp	x20, x19, [sp, #80]
   51144: a94457f6     	ldp	x22, x21, [sp, #64]
   51148: a9427bfd     	ldp	x29, x30, [sp, #32]
   5114c: f9401bf7     	ldr	x23, [sp, #48]
   51150: 910183ff     	add	sp, sp, #96
   51154: d65f03c0     	ret
