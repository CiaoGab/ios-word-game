#!/usr/bin/env python3
"""
WordFall asset generator.
Produces:
  AppIcon.png (1024x1024) – light, dark, and tinted variants
  logo@1x/2x/3x.png       – home screen hero graphic

Run from repo root:
  python3 scripts/gen_assets.py
"""

import math
import pathlib
from PIL import Image, ImageDraw, ImageFont

REPO = pathlib.Path(__file__).resolve().parent.parent
ASSETS = REPO / "ios-word-game" / "Assets.xcassets"
ICON_DIR = ASSETS / "AppIcon.appiconset"
LOGO_DIR = ASSETS / "logo.imageset"
LOGO_DIR.mkdir(exist_ok=True)

# ── Palette ──────────────────────────────────────────────────────────────────
ivory        = (253, 246, 227)       # #FDF6E3  canvas
ivory_dark   = (245, 237, 215)
tile_fill    = (255, 255, 253)       # white-warm
tile_stroke  = (166, 124, 46)        # #A67C2E  gold stroke
ink          = (31,  35,  41)        # #1F2329  charcoal
gold         = (199, 154,  59)       # #C79A3B  accent gold
gold_soft    = (232, 213, 163)       # #E8D5A3
gold_muted   = (180, 140,  50)

# Dark-mode palette
dark_bg      = (24,  20,  14)
dark_tile    = (38,  32,  22)
dark_stroke  = (180, 140,  50)
dark_ink     = (242, 237, 220)

# ── Fonts ────────────────────────────────────────────────────────────────────
FUTURA = "/System/Library/Fonts/Supplemental/Futura.ttc"
GEORGIA = "/System/Library/Fonts/Supplemental/Georgia.ttf"
HELVETICA = "/System/Library/Fonts/Helvetica.ttc"


def load_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def rgba(rgb, a=255):
    return (*rgb, a)


def draw_rounded_rect(draw, box, radius, fill, stroke=None, stroke_width=0):
    x0, y0, x1, y1 = box
    if stroke and stroke_width > 0:
        hw = stroke_width
        draw.rounded_rectangle([x0-hw, y0-hw, x1+hw, y1+hw], radius=radius+hw, fill=rgba(stroke))
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=rgba(fill))


def draw_lock(draw, cx, cy, size, body_color, shackle_color):
    """Draw a padlock icon centred at (cx, cy) with given size."""
    bw = size * 0.60          # body width
    bh = size * 0.48          # body height
    bx0 = cx - bw / 2
    by0 = cy - bh * 0.20
    bx1 = cx + bw / 2
    by1 = cy + bh * 0.80
    brad = size * 0.10
    draw.rounded_rectangle([bx0, by0, bx1, by1], radius=brad, fill=rgba(body_color))

    # Keyhole: circle + slot
    kc = size * 0.10
    kx, ky = cx, cy + bh * 0.15
    draw.ellipse([kx-kc, ky-kc, kx+kc, ky+kc], fill=rgba(shackle_color))
    draw.rectangle([kx - kc*0.35, ky, kx + kc*0.35, ky + kc*1.4], fill=rgba(shackle_color))

    # Shackle (U arc drawn as thick arc)
    sw = size * 0.48          # shackle width
    sh = size * 0.38          # shackle height
    sx0 = cx - sw / 2
    sy0 = by0 - sh
    sx1 = cx + sw / 2
    sy1 = by0 + sh * 0.10
    lw = max(2, int(size * 0.10))
    draw.arc([sx0, sy0, sx1, sy1], start=180, end=0, fill=rgba(shackle_color), width=lw)
    # Vertical legs of shackle
    draw.line([sx0 + lw//2, (sy0+sy1)//2, sx0 + lw//2, by0 + lw//2],
              fill=rgba(shackle_color), width=lw)
    draw.line([sx1 - lw//2, (sy0+sy1)//2, sx1 - lw//2, by0 + lw//2],
              fill=rgba(shackle_color), width=lw)


def draw_tile(draw, x, y, w, h, letter, point_val,
              fill, stroke_col, letter_col, val_col,
              font_letter, font_val, corner_r=None):
    if corner_r is None:
        corner_r = w * 0.18
    sw = max(2, int(w * 0.045))
    draw_rounded_rect(draw, [x, y, x+w, y+h], corner_r, fill, stroke_col, sw)

    # Letter
    bbox = draw.textbbox((0, 0), letter, font=font_letter)
    lw = bbox[2] - bbox[0]
    lh = bbox[3] - bbox[1]
    lx = x + (w - lw) / 2 - bbox[0]
    ly = y + (h - lh) / 2 - bbox[1] - h * 0.04
    draw.text((lx, ly), letter, font=font_letter, fill=rgba(letter_col))

    # Point value (bottom-right)
    vbbox = draw.textbbox((0, 0), str(point_val), font=font_val)
    vw = vbbox[2] - vbbox[0]
    draw.text(
        (x + w - vw - w*0.10 - vbbox[0], y + h - h*0.22 - vbbox[1]),
        str(point_val), font=font_val, fill=rgba(val_col)
    )


# ─────────────────────────────────────────────────────────────────────────────
#  APP ICON
# ─────────────────────────────────────────────────────────────────────────────

def make_icon(size=1024, dark=False, tinted=False):
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)

    bg   = dark_bg   if dark else ivory
    tf   = dark_tile  if dark else tile_fill
    tstr = dark_stroke if dark else tile_stroke
    ink_ = dark_ink   if dark else ink

    if tinted:
        # Tinted = monochromatic; Xcode composites the tint colour on top.
        # Output a greyscale-ready version using a mid-grey BG.
        bg   = (160, 130, 80)
        tf   = (200, 180, 130)
        tstr = (255, 255, 255)
        ink_ = (255, 255, 255)

    # Background with slight gradient feel (fake via two blended rects)
    draw.rectangle([0, 0, size, size], fill=rgba(bg))
    if not dark and not tinted:
        # Subtle warm gradient: slightly darker corners
        grad_color = (243, 234, 210, 30)
        draw.ellipse([-size//4, -size//4, size*5//4, size*5//4],
                     fill=grad_color)

    s = size / 1024  # scale factor

    # --- Falling background tiles (small, muted) ---
    bg_tile_data = [
        # (x_center, y_center, width, letter, pts, angle_deg)
        (size*0.17, size*0.22, size*0.16, "O", 1, -14),
        (size*0.82, size*0.28, size*0.14, "R", 1, 12),
        (size*0.13, size*0.76, size*0.13, "D", 2, -8),
        (size*0.86, size*0.72, size*0.15, "L", 1, 16),
        (size*0.50, size*0.12, size*0.12, "F", 4, -5),
        (size*0.72, size*0.88, size*0.13, "A", 1, 10),
    ]
    f_small = load_font(FUTURA, int(80 * s))
    f_tiny  = load_font(FUTURA, int(26 * s))

    for bx, by, bw, bl, bpts, angle in bg_tile_data:
        bh = bw * 1.10
        alpha = 55 if not dark else 45
        # Create small tile image, draw, rotate, paste
        tile_img = Image.new("RGBA", (int(bw*2), int(bh*2)), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile_img)
        tx, ty = bw//2, bh//2
        sw2 = max(1, int(bw * 0.05))
        if dark:
            tf2 = tuple(min(255, c+25) for c in dark_tile)
        else:
            tf2 = (250, 244, 230)
        td.rounded_rectangle([tx - bw//2, ty - bh//2, tx + bw//2, ty + bh//2],
                              radius=bw*0.15, fill=(*tf2, alpha))
        td.rounded_rectangle([tx - bw//2 + sw2, ty - bh//2 + sw2,
                               tx + bw//2 - sw2, ty + bh//2 - sw2],
                              radius=bw*0.12, fill=(0, 0, 0, 0))
        td.rounded_rectangle([tx - bw//2, ty - bh//2, tx + bw//2, ty + bh//2],
                              radius=bw*0.15, fill=(*tf2, alpha))
        lbb = td.textbbox((0, 0), bl, font=f_small)
        td.text((tx - (lbb[2]-lbb[0])//2 - lbb[0],
                 ty - (lbb[3]-lbb[1])//2 - lbb[1] - bh*0.04),
                bl, font=f_small,
                fill=(*ink_, alpha))
        tile_img = tile_img.rotate(angle, expand=False, resample=Image.BICUBIC)
        cx_paste = int(bx - tile_img.width // 2)
        cy_paste = int(by - tile_img.height // 2)
        img.paste(tile_img, (cx_paste, cy_paste), tile_img)

    # --- Main "W" tile ---
    mw = int(size * 0.56)
    mh = int(mw * 1.08)
    mx = (size - mw) // 2
    my = (size - mh) // 2 + int(size * 0.02)

    # Tile shadow
    shadow_offset = int(size * 0.018)
    shadow_alpha = 55 if not dark else 90
    draw.rounded_rectangle(
        [mx + shadow_offset, my + shadow_offset,
         mx + mw + shadow_offset, my + mh + shadow_offset],
        radius=mw*0.16,
        fill=(0, 0, 0, shadow_alpha)
    )

    # Tile border (gold stroke)
    bsw = max(3, int(mw * 0.042))
    draw.rounded_rectangle([mx - bsw, my - bsw, mx + mw + bsw, my + mh + bsw],
                            radius=mw*0.16 + bsw,
                            fill=rgba(tstr if tinted else tile_stroke))
    # Tile body
    draw.rounded_rectangle([mx, my, mx + mw, my + mh],
                            radius=mw*0.16,
                            fill=rgba(tf))

    # Inner inset line (subtle premium detail)
    inset = int(mw * 0.05)
    inset_alpha = 35 if not dark else 60
    draw.rounded_rectangle(
        [mx + inset, my + inset, mx + mw - inset, my + mh - inset],
        radius=mw*0.12,
        fill=(0, 0, 0, 0),
        outline=(*tile_stroke, inset_alpha),
        width=max(1, int(mw * 0.012))
    )

    # "W" letter
    f_W = load_font(FUTURA, int(size * 0.36))
    wbb = draw.textbbox((0, 0), "W", font=f_W)
    wx = mx + (mw - (wbb[2]-wbb[0])) // 2 - wbb[0]
    wy = my + (mh - (wbb[3]-wbb[1])) // 2 - wbb[1] - int(mh * 0.04)
    draw.text((wx, wy), "W", font=f_W, fill=rgba(ink_))

    # Point value "4" bottom-right
    f_pv = load_font(FUTURA, int(size * 0.09))
    pvbb = draw.textbbox((0, 0), "4", font=f_pv)
    pvx = mx + mw - (pvbb[2]-pvbb[0]) - int(mw*0.11) - pvbb[0]
    pvy = my + mh - (pvbb[3]-pvbb[1]) - int(mh*0.09) - pvbb[1]
    gval = gold_muted if not dark else gold
    draw.text((pvx, pvy), "4", font=f_pv, fill=rgba(gval))

    # --- Lock badge (bottom-right corner of icon) ---
    badge_r = int(size * 0.155)
    badge_cx = int(size * 0.80)
    badge_cy = int(size * 0.80)
    badge_bg = gold if not dark else gold
    if tinted:
        badge_bg = (220, 200, 150)

    # Badge circle
    draw.ellipse(
        [badge_cx - badge_r, badge_cy - badge_r,
         badge_cx + badge_r, badge_cy + badge_r],
        fill=rgba(badge_bg)
    )
    # Lock icon inside badge
    lock_col  = ivory if not dark else dark_bg
    lock_col2 = ivory if not dark else dark_bg
    draw_lock(draw, badge_cx, badge_cy, badge_r * 1.35, lock_col, lock_col2)

    return img


# ─────────────────────────────────────────────────────────────────────────────
#  HOME SCREEN GRAPHIC  (logo)
# ─────────────────────────────────────────────────────────────────────────────

def make_logo(w=720, h=200):
    """
    Horizontal hero graphic: 3 cascading letter tiles + wordmark text.
    Transparent background so it composites over any surface.
    """
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    tile_sz = int(h * 0.72)
    tile_h  = int(tile_sz * 1.08)

    # Letters: W, O, R — cascading left to right
    letters = [
        ("W", 4, -6),
        ("O", 1,  2),
        ("R", 1, -4),
    ]

    f_letter = load_font(FUTURA, int(tile_sz * 0.60))
    f_val    = load_font(FUTURA, int(tile_sz * 0.20))
    f_title  = load_font(FUTURA, int(h * 0.36))
    f_sub    = load_font(FUTURA, int(h * 0.155))

    tile_gap = int(tile_sz * 0.18)
    total_tile_w = len(letters) * tile_sz + (len(letters)-1) * tile_gap
    tile_start_x = int(w * 0.04)

    offsets_y = [int(h*0.14), int(h*0.04), int(h*0.20)]

    for i, (letter, pts, _angle) in enumerate(letters):
        tx = tile_start_x + i * (tile_sz + tile_gap)
        ty = (h - tile_h) // 2 + offsets_y[i]

        # Shadow
        sh_off = int(tile_sz * 0.025)
        draw.rounded_rectangle(
            [tx+sh_off, ty+sh_off, tx+tile_sz+sh_off, ty+tile_h+sh_off],
            radius=tile_sz*0.18, fill=(0, 0, 0, 30)
        )
        # Border
        bsw = max(2, int(tile_sz * 0.040))
        draw.rounded_rectangle(
            [tx-bsw, ty-bsw, tx+tile_sz+bsw, ty+tile_h+bsw],
            radius=tile_sz*0.18+bsw, fill=rgba(tile_stroke)
        )
        # Fill
        draw.rounded_rectangle(
            [tx, ty, tx+tile_sz, ty+tile_h],
            radius=tile_sz*0.18, fill=rgba(tile_fill)
        )
        # Letter
        lbb = draw.textbbox((0, 0), letter, font=f_letter)
        lx = tx + (tile_sz - (lbb[2]-lbb[0])) // 2 - lbb[0]
        ly = ty + (tile_h - (lbb[3]-lbb[1])) // 2 - lbb[1] - tile_h*0.04
        draw.text((lx, ly), letter, font=f_letter, fill=rgba(ink))
        # Point value
        pvbb = draw.textbbox((0, 0), str(pts), font=f_val)
        draw.text(
            (tx + tile_sz - pvbb[2] + pvbb[0] - tile_sz*0.10 - pvbb[0],
             ty + tile_h - pvbb[3] + pvbb[1] - tile_h*0.10 - pvbb[1]),
            str(pts), font=f_val, fill=rgba(gold)
        )

    # Text area
    text_x = tile_start_x + total_tile_w + int(w * 0.06)
    # "WordFall"
    tbb = draw.textbbox((0, 0), "WordFall", font=f_title)
    ty_title = (h - (tbb[3]-tbb[1])) // 2 - int(h*0.06) - tbb[1]
    draw.text((text_x - tbb[0], ty_title), "WordFall", font=f_title, fill=rgba(ink))
    # Subtitle
    sbb = draw.textbbox((0, 0), "Break locks. Build words.", font=f_sub)
    ty_sub = ty_title + (tbb[3]-tbb[1]) + int(h * 0.06) - sbb[1]
    draw.text((text_x - sbb[0], ty_sub), "Break locks. Build words.",
              font=f_sub, fill=rgba((100, 90, 70)))

    return img


# ─────────────────────────────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("Generating app icons...")
    light  = make_icon(1024, dark=False,  tinted=False)
    dark   = make_icon(1024, dark=True,   tinted=False)
    tinted = make_icon(1024, dark=False,  tinted=True)

    light.save(str(ICON_DIR / "AppIcon.png"))
    dark.save(str(ICON_DIR / "AppIcon-Dark.png"))
    tinted.save(str(ICON_DIR / "AppIcon-Tinted.png"))
    print(f"  Wrote AppIcon.png, AppIcon-Dark.png, AppIcon-Tinted.png -> {ICON_DIR}")

    # Update Contents.json
    import json
    contents = {
        "images": [
            {"filename": "AppIcon.png",        "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"filename": "AppIcon-Dark.png",   "idiom": "universal", "platform": "ios", "size": "1024x1024",
             "appearances": [{"appearance": "luminosity", "value": "dark"}]},
            {"filename": "AppIcon-Tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024",
             "appearances": [{"appearance": "luminosity", "value": "tinted"}]},
        ],
        "info": {"author": "xcode", "version": 1}
    }
    (ICON_DIR / "Contents.json").write_text(json.dumps(contents, indent=2))
    print("  Updated AppIcon Contents.json")

    print("\nGenerating home screen logo...")
    for scale, (w, h) in [(1, (360, 100)), (2, (720, 200)), (3, (1080, 300))]:
        logo = make_logo(w, h)
        fname = f"logo@{scale}x.png"
        logo.save(str(LOGO_DIR / fname))
        print(f"  Wrote {fname} -> {LOGO_DIR}")

    logo_contents = {
        "images": [
            {"filename": "logo@1x.png", "idiom": "universal", "scale": "1x"},
            {"filename": "logo@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": "logo@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1}
    }
    import json as _json
    (LOGO_DIR / "Contents.json").write_text(_json.dumps(logo_contents, indent=2))
    print("  Wrote logo Contents.json")
    print("\nDone.")


if __name__ == "__main__":
    main()
