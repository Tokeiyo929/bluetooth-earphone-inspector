#!/usr/bin/env python3
"""生成 AppIcon（1024×1024，不透明方图）。设计源见同目录 icon.svg。

本机没有 cairo，用 Pillow 复刻栅格：4 倍超采样 + LANCZOS 缩小，
曲线用「沿路径盖圆盘」画法避免折线接缝。
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

S = 4                      # 超采样倍数
W = 1024
OUT = Path(__file__).resolve().parents[2] / "ios" / "App" / "App" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

NAVY = (8, 16, 34)
TEAL = (6, 74, 92)
WHITE = (255, 255, 255)
CYAN = (34, 211, 238)


def gradient(size: int) -> Image.Image:
    """顶部深海军蓝 → 底部青绿的竖直渐变。"""
    base = Image.linear_gradient("L").resize((size, size))
    return ImageOps.colorize(base, black=NAVY, white=TEAL).convert("RGB")


def thick_line(draw: ImageDraw.ImageDraw, points, width: int, fill):
    """沿路径盖圆盘 + 连线，避免 line 的斜接缺口。"""
    r = width / 2
    draw.line(points, fill=fill, width=width, joint="curve")
    for x, y in points:
        draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def main() -> None:
    px = W * S
    canvas = gradient(px)
    draw = ImageDraw.Draw(canvas)
    scale = S

    # 头梁：上半圆弧
    band_width = 62 * scale
    draw.arc(
        [212 * scale, 260 * scale, 812 * scale, 860 * scale],
        start=180, end=360, fill=WHITE, width=band_width,
    )

    # 左右耳罩
    for cx in (240, 784):
        draw.rounded_rectangle(
            [(cx - 85) * scale, 545 * scale, (cx + 85) * scale, 815 * scale],
            radius=82 * scale, fill=WHITE,
        )
        # 耳罩上的充电触点小圆，给纯白块一点细节
        draw.ellipse(
            [(cx - 22) * scale, 668 * scale, (cx + 22) * scale, 712 * scale],
            fill=CYAN,
        )

    # 蓝牙符文（青色，圆头）
    rune = [
        [(512, 418), (512, 672)],
        [(512, 418), (642, 486), (512, 552)],
        [(512, 552), (642, 618), (512, 672)],
    ]
    for path in rune:
        thick_line(draw, [(x * scale, y * scale) for x, y in path], 30 * scale, CYAN)

    icon = canvas.resize((W, W), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUT, "PNG")
    print(f"wrote {OUT} ({icon.size[0]}x{icon.size[1]}, mode={icon.mode})")


if __name__ == "__main__":
    main()
