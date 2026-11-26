"""Renders assets/samples/sample_notice.png, the synthetic notice behind
"Try a sample notice" on the Scan page.

Usage:
    python tool/render_sample_notice.py [output.png]

Change DEADLINE below to move the bid deadline; everything else stays put.
The deadline must stay in the future on demo day, or the hard rules veto
the scanned tender and the AI never runs.

Needs Pillow and the Arial and Times New Roman fonts. They are read from
C:/Windows/Fonts unless the FONT_DIR environment variable points elsewhere.
"""
import os
import sys
import textwrap

from PIL import Image, ImageDraw, ImageFont

DEADLINE = "30 June 2027 at 14:00 hours"

OUTPUT = "assets/samples/sample_notice.png"
SIZE = (1240, 1754)  # A4 at 150 dpi
PAPER = (252, 251, 247)
HEADING_INK = (20, 20, 20)
BODY_INK = (25, 25, 25)
FONT_DIR = os.environ.get("FONT_DIR", "C:/Windows/Fonts")

# (text, font file, size, top). Centred on the page.
HEADINGS = [
    ("SAMPLE NOTICE - SYNTHETIC DATA FOR TESTING", "arial.ttf", 22, 40),
    ("MINISTRY OF HEALTH - WESTERN PROVINCE", "arialbd.ttf", 30, 90),
    ("SRI LANKA", "arialbd.ttf", 30, 140),
    ("INVITATION FOR BIDS", "arialbd.ttf", 46, 220),
    ("Supply and Installation of a Hospital Appointment", "arialbd.ttf", 30, 300),
    ("and Patient Records System", "arialbd.ttf", 30, 342),
]

BODY_LEFT = 110
BODY_TOP = 412
BODY_SIZE = 30
WRAP_CHARS = 72
LINE_STEP = 40
PARAGRAPH_GAP = 18

PARAGRAPHS = [
    "Bid Reference: WP/MOH/IT/2026/14",
    "1. The Ministry of Health, Western Province, invites sealed bids from "
    "eligible bidders for the supply, installation and two years of support "
    "of a hospital appointment and patient records system for 12 provincial "
    "hospitals.",
    "2. Bidders must hold ISO 9001 certification.",
    "3. Bidders must have a minimum of 3 years of experience in delivering "
    "health software.",
    "4. Bidders must have an average annual turnover of at least LKR "
    "150,000,000 over the last three years.",
    "5. A bid security of LKR 500,000 must accompany each bid.",
    f"6. Bids must be submitted no later than {DEADLINE} to the Procurement "
    "Unit, Ministry of Health, Colombo 07. Late bids will be rejected.",
    "7. Bidding documents may be obtained from the address above on payment "
    "of a non-refundable fee of LKR 5,000.",
]
SIGNATURE = "Chairman, Provincial Procurement Committee"


def font(name, size):
    return ImageFont.truetype(os.path.join(FONT_DIR, name), size)


def draw_headings(draw):
    centre = SIZE[0] / 2
    for text, name, size, top in HEADINGS:
        draw.text((centre, top), text, font=font(name, size), fill=HEADING_INK,
                  anchor="ma")


def draw_body(draw):
    body = font("times.ttf", BODY_SIZE)
    y = BODY_TOP
    for paragraph in PARAGRAPHS:
        for line in textwrap.wrap(paragraph, WRAP_CHARS):
            draw.text((BODY_LEFT, y), line, font=body, fill=BODY_INK)
            y += LINE_STEP
        y += PARAGRAPH_GAP
    # One blank line before the signature.
    draw.text((BODY_LEFT, y + LINE_STEP), SIGNATURE, font=body, fill=BODY_INK)


def render(path):
    image = Image.new("RGB", SIZE, PAPER)
    draw = ImageDraw.Draw(image)
    draw_headings(draw)
    draw_body(draw)
    image.save(path, optimize=True)


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else OUTPUT)
