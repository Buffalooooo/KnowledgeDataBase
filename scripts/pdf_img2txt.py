"""
PDF 图片转文字工具 (OCR) —— 轻量版
======================================
无需安装 Tesseract OCR 引擎，利用 Windows 10/11 内置 OCR 能力。
安装极简：pip install pymupdf pillow winrt

使用示例：
    python pdf_img2txt.py sample.pdf
    python pdf_img2txt.py sample.pdf -o output.txt
    python pdf_img2txt.py sample.pdf --dpi 400
    python pdf_img2txt.py ./pdfs/ -o ./output/
"""

import argparse
import asyncio
import os
import sys
import tempfile
from pathlib import Path

import fitz  # PyMuPDF
from PIL import Image

# ── 尝试加载 Windows 内置 OCR ──────────────────────────────────────────
try:
    import winrt.windows.graphics.imaging as wgi
    import winrt.windows.media.ocr as wocr
    from winrt.windows.storage import StorageFile, FileAccessMode
    HAS_WINRT = True
except ImportError:
    HAS_WINRT = False


def _preprocess(img: Image.Image) -> Image.Image:
    """轻量预处理：转灰度 + 增强对比度"""
    from PIL import ImageEnhance
    img = img.convert("L")
    img = ImageEnhance.Contrast(img).enhance(1.8)
    return img


# ── 后端一：Windows 内置 OCR（轻量，首选）─────────────────────────────

async def _winrt_ocr_single(img: Image.Image) -> str:
    """用 Windows.Media.Ocr 识别一张图片"""
    # 获取 Windows OCR 允许的最大尺寸，超出则等比缩放
    max_dim = wocr.OcrEngine.max_image_dimension  # 通常为 2048

    # 等比缩放
    width, height = img.size
    if width > max_dim or height > max_dim:
        ratio = min(max_dim / width, max_dim / height)
        new_w = int(width * ratio)
        new_h = int(height * ratio)
        img = img.resize((new_w, new_h), Image.LANCZOS)

    # 存临时文件供 WinRT API 读取
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        tmp_path = tmp.name
        img.save(tmp_path, format="PNG")

    try:
        storage_file = await StorageFile.get_file_from_path_async(tmp_path)
        stream = await storage_file.open_read_async()
        decoder = await wgi.BitmapDecoder.create_async(stream)
        sbmp = await decoder.get_software_bitmap_async()

        # 根据系统语言创建 OCR 引擎（中文系统自带中文字库）
        engine = wocr.OcrEngine.try_create_from_user_profile_languages()
        if engine is None:
            # 回退到英语
            from winrt.windows.globalization import Language
            engine = wocr.OcrEngine.try_create_from_language(Language("en"))

        result = await engine.recognize_async(sbmp)
        return result.text.strip()
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


def ocr_page_winrt(page: fitz.Page, dpi: int) -> str:
    """渲染 PDF 页 → Windows OCR 识别"""
    mat = fitz.Matrix(dpi / 72, dpi / 72)
    pix = page.get_pixmap(matrix=mat)
    img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
    img = _preprocess(img)
    return asyncio.run(_winrt_ocr_single(img))


# ── 后端二：Pillow 像素对比（零依赖，极简后备）───────────────────────
#     用于某些扫描件中文字是黑底白字等简单场景，无需任何 OCR 引擎

def ocr_page_simple(page: fitz.Page, dpi: int) -> str:
    """极简方案：只输出字符轮廓提示（实际用处有限，仅为演示无依赖可用）"""
    mat = fitz.Matrix(dpi / 72, dpi / 72)
    pix = page.get_pixmap(matrix=mat)
    img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
    img = _preprocess(img)

    # 检测是否有足够多的暗像素，判断是否有文字内容
    import statistics
    pixels = list(img.getdata())
    avg = statistics.mean(pixels)
    text_ratio = sum(1 for p in pixels if p < 128) / len(pixels)

    if text_ratio < 0.01:
        return "[此页似乎为空白]"

    # 返回基本信息（此方法无法真正识别文字，仅输出占位提示）
    return f"[检测到文字内容，覆盖率 {text_ratio:.1%}，平均亮度 {avg:.0f}，\n" \
           f" 请使用 Windows OCR 后端（默认）获得完整识别结果]"


# ── 流程控制 ────────────────────────────────────────────────────────────

def ocr_page(page: fitz.Page, dpi: int, backend: str) -> str:
    if backend == "winrt":
        return ocr_page_winrt(page, dpi)
    else:
        return ocr_page_simple(page, dpi)


def process_pdf(pdf_path: Path, output_path: Path, dpi: int, backend: str):
    """处理单个 PDF 文件"""
    print(f"\n📄 正在处理：{pdf_path.name}  [后端: {backend}]")
    try:
        doc = fitz.open(str(pdf_path))
    except Exception as e:
        print(f"   ❌ 无法打开 PDF：{e}")
        return

    total_pages = len(doc)
    print(f"  总页数：{total_pages}")

    all_text = []
    for i in range(total_pages):
        page = doc[i]
        page_num = i + 1
        print(f"  ⏳ 识别第 {page_num}/{total_pages} 页...", end="\r")
        try:
            text = ocr_page(page, dpi, backend)
            all_text.append(f"--- 第 {page_num} 页 ---\n{text}")
        except Exception as e:
            all_text.append(f"--- 第 {page_num} 页 ---\n[识别失败：{e}]")
            print(f"\n  ⚠️  第 {page_num} 页识别出错：{e}")

    print(f"\n  ✅ 识别完成！共 {total_pages} 页")
    doc.close()

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(f"来源：{pdf_path.name}\n")
        f.write(f"页数：{total_pages}\n")
        f.write("=" * 50 + "\n\n")
        f.write("\n\n".join(all_text))

    print(f"  📝 已保存至：{output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="PDF 图片转文字（OCR）工具 —— 轻量版",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
后端选择：
  winrt   使用 Windows 内置 OCR（默认，推荐，Win10/11 无需装引擎）
  simple  极简模式，无依赖但仅能检测文字有无，无法识别内容

示例：
  pdf_img2txt.py sample.pdf
  pdf_img2txt.py sample.pdf -o result.txt
  pdf_img2txt.py sample.pdf --dpi 400
  pdf_img2txt.py sample.pdf --backend simple
  pdf_img2txt.py ./pdfs/ -o ./output/
        """,
    )
    parser.add_argument("input", help="输入的 PDF 文件路径或包含 PDF 的文件夹路径")
    parser.add_argument("-o", "--output", help="输出文件路径（输入为文件时）或输出文件夹路径（输入为文件夹时）")
    parser.add_argument("--dpi", type=int, default=300, help="PDF 渲染分辨率（默认：300）")
    parser.add_argument(
        "--backend", choices=["winrt", "simple"], default="winrt",
        help="OCR 后端：winrt（推荐）或 simple（极简占位，默认：winrt）",
    )

    args = parser.parse_args()

    # 检查后端可用性
    if args.backend == "winrt" and not HAS_WINRT:
        print("⚠️  未安装 winrt，无法使用 Windows 内置 OCR。")
        print("   请运行：pip install winrt")
        print("   或使用 --backend simple 以极简模式运行（只能检测有无文字，无法识别内容）")
        sys.exit(1)

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"❌ 路径不存在：{input_path}")
        sys.exit(1)

    if args.input.endswith(".pdf"):
        out_path = Path(args.output) if args.output else input_path.with_suffix(".txt")
        process_pdf(input_path, out_path, args.dpi, args.backend)
    else:
        pdf_files = list(input_path.rglob("*.pdf"))
        if not pdf_files:
            print(f"⚠️ 在 {input_path} 下未找到 PDF 文件")
            sys.exit(0)

        out_dir = Path(args.output) if args.output else input_path / "_ocr_output"
        print(f"📂 共找到 {len(pdf_files)} 个 PDF 文件，输出目录：{out_dir}")

        for pdf_file in pdf_files:
            rel_path = pdf_file.relative_to(input_path)
            out_file = out_dir / rel_path.with_suffix(".txt")
            process_pdf(pdf_file, out_file, args.dpi, args.backend)

    print("\n🎉 全部处理完成！")


if __name__ == "__main__":
    main()
