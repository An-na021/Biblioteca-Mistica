"""Gera o PDF das ADRs e um ZIP do código-fonte sem caches ou dados locais."""

import argparse
import hashlib
import html
from pathlib import Path
import re
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PDF_PATH = ROOT / "output/pdf/Biblioteca_ADRs.pdf"
PACKAGE_PATH = ROOT / "output/entrega/Biblioteca_projeto.zip"


def inline(text):
    text = html.escape(text)
    text = re.sub(r"`([^`]+)`", r'<font name="DeliveryMono">\1</font>', text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", text)


def make_pdf():
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_LEFT
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.platypus import (
        HRFlowable, PageBreak, Paragraph, SimpleDocTemplate, Spacer,
    )

    font_candidates = [
        (Path("C:/Windows/Fonts"), "segoeui.ttf", "segoeuib.ttf", "consola.ttf"),
        (Path("/usr/share/fonts/truetype/dejavu"), "DejaVuSans.ttf", "DejaVuSans-Bold.ttf", "DejaVuSansMono.ttf"),
    ]
    for directory, regular, bold, mono in font_candidates:
        if all((directory / name).exists() for name in (regular, bold, mono)):
            for alias, name in [("Delivery", regular), ("DeliveryBold", bold), ("DeliveryMono", mono)]:
                pdfmetrics.registerFont(TTFont(alias, str(directory / name)))
            pdfmetrics.registerFontFamily("Delivery", normal="Delivery", bold="DeliveryBold", italic="Delivery", boldItalic="DeliveryBold")
            break
    else:
        pdfmetrics.registerFont(pdfmetrics.Font("Delivery", "Helvetica", "WinAnsiEncoding"))
        pdfmetrics.registerFont(pdfmetrics.Font("DeliveryBold", "Helvetica-Bold", "WinAnsiEncoding"))
        pdfmetrics.registerFont(pdfmetrics.Font("DeliveryMono", "Courier", "WinAnsiEncoding"))
        pdfmetrics.registerFontFamily("Delivery", normal="Delivery", bold="DeliveryBold")

    forest = colors.HexColor("#214D3B")
    muted = colors.HexColor("#56665D")
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name="BodyDelivery", fontName="Delivery", fontSize=10.2, leading=15.2, spaceAfter=8, textColor=colors.HexColor("#24352C"), alignment=TA_LEFT))
    styles.add(ParagraphStyle(name="SectionDelivery", fontName="DeliveryBold", fontSize=12, leading=16, textColor=forest, spaceBefore=12, spaceAfter=7, keepWithNext=True))
    styles.add(ParagraphStyle(name="TitleDelivery", fontName="DeliveryBold", fontSize=23, leading=29, textColor=forest, spaceAfter=16, keepWithNext=True))
    styles.add(ParagraphStyle(name="LabelDelivery", fontName="DeliveryBold", fontSize=9, leading=13, textColor=muted, spaceAfter=12))
    styles.add(ParagraphStyle(name="ListDelivery", parent=styles["BodyDelivery"], leftIndent=11, firstLineIndent=-9, spaceAfter=5))

    def footer(canvas, document):
        width, height = A4
        canvas.saveState()
        canvas.setStrokeColor(colors.HexColor("#CFD9D1"))
        canvas.line(22 * mm, 18 * mm, width - 22 * mm, 18 * mm)
        canvas.setFont("Delivery", 8)
        canvas.setFillColor(muted)
        canvas.drawString(22 * mm, 12 * mm, "BIBLIOTECA  /  DECISÕES DE ARQUITETURA")
        canvas.drawRightString(width - 22 * mm, 12 * mm, str(document.page))
        if document.page > 1:
            canvas.setFont("Delivery", 8)
            canvas.drawString(22 * mm, height - 14 * mm, "ENTREGA DO PROJETO  /  26 NOV 2026")
        canvas.restoreState()

    story = [
        Spacer(1, 25 * mm),
        Paragraph("DOCUMENTAÇÃO TÉCNICA / 26 NOV 2026", styles["LabelDelivery"]),
        Paragraph("Biblioteca", styles["TitleDelivery"]),
        Paragraph("Registros de decisões<br/>de arquitetura", styles["TitleDelivery"]),
        HRFlowable(width="100%", thickness=2, color=forest, spaceAfter=20),
        Paragraph("Jogo de gestão de livraria em Godot, com API de catálogo em Python e persistência SQLite.", styles["BodyDelivery"]),
        Spacer(1, 8 * mm),
        Paragraph("DECISÕES DOCUMENTADAS", styles["LabelDelivery"]),
        Paragraph("<b>ADR-001</b> - Organização modular e comunicação por eventos.", styles["BodyDelivery"]),
        Paragraph("<b>ADR-002</b> - Catálogo por API, fallback local e preservação da partida.", styles["BodyDelivery"]),
        Paragraph("<b>ADR-003</b> - Expiração em massa de reservas temporárias de exemplares.", styles["BodyDelivery"]),
        Paragraph("<b>ADR-004</b> - Identidade local e pagamento com entrega atômica.", styles["BodyDelivery"]),
        Spacer(1, 12 * mm),
        Paragraph("Os registros descrevem decisões observadas na implementação atual. Contexto, alternativas, consequências e evidências permitem relacionar as escolhas ao código entregue.", styles["BodyDelivery"]),
        Paragraph("O cenário da entrega 1 foi adaptado de assentos para exemplares de livros, conforme orientação recebida. A documentação distingue a implementação funcional dos resultados medidos em testes locais.", styles["BodyDelivery"]),
    ]

    source = (ROOT / "docs/ADRS.md").read_text(encoding="utf-8")
    in_adr = False
    paragraph = []

    def flush():
        if paragraph:
            story.append(Paragraph(inline(" ".join(paragraph)), styles["BodyDelivery"]))
            paragraph.clear()

    for line in source.splitlines():
        stripped = line.strip()
        if re.match(r"^## ADR[- ]?\d", stripped):
            flush()
            story.append(PageBreak())
            story.append(Paragraph(inline(stripped[3:]), styles["TitleDelivery"]))
            in_adr = True
        elif not in_adr:
            continue
        elif stripped.startswith("### "):
            flush()
            story.append(Paragraph(inline(stripped[4:]), styles["SectionDelivery"]))
        elif stripped.startswith("- "):
            flush()
            story.append(Paragraph("- " + inline(stripped[2:]), styles["ListDelivery"]))
        elif re.match(r"^\d+\. ", stripped):
            flush()
            story.append(Paragraph(inline(stripped), styles["ListDelivery"]))
        elif not stripped:
            flush()
        else:
            paragraph.append(stripped)
    flush()
    if not in_adr:
        raise ValueError("docs/ADRS.md precisa conter títulos '## ADR-001' e '## ADR-002'.")
    PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(str(PDF_PATH), pagesize=A4, rightMargin=22 * mm, leftMargin=22 * mm, topMargin=24 * mm, bottomMargin=25 * mm, title="Biblioteca - Registros de decisões de arquitetura", author="Projeto Biblioteca")
    document.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"PDF: {PDF_PATH.relative_to(ROOT)}")


def make_package():
    required = ["project.godot", "README.md", "docs/INSTALACAO_E_USO.md", "docs/ARQUITETURA.md", "docs/ADRS.md", "docs/ENTREGA.md", "output/pdf/Biblioteca_ADRs.pdf"]
    for name in required:
        if not (ROOT / name).is_file():
            raise FileNotFoundError(f"Arquivo obrigatório ausente: {name}")
    paths = subprocess.check_output(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT).decode("utf-8").split("\0")
    excluded = {".git", ".godot", ".venv", "__pycache__", "tmp", ".pytest_cache"}
    files = []
    for name in sorted(set(filter(None, paths))):
        path = Path(name)
        if any(part in excluded for part in path.parts) or name.startswith(("api/data/", "output/entrega/")):
            continue
        if path.name.startswith(".env") and not path.name.endswith(".example"):
            continue
        if (ROOT / path).is_file():
            files.append(path)
    PACKAGE_PATH.parent.mkdir(parents=True, exist_ok=True)
    checksums = []
    with zipfile.ZipFile(PACKAGE_PATH, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            content = (ROOT / path).read_bytes()
            name = "Biblioteca/" + path.as_posix()
            archive.writestr(name, content)
            checksums.append(f"{hashlib.sha256(content).hexdigest()}  {path.as_posix()}")
        archive.writestr("Biblioteca/MANIFESTO_SHA256.txt", "\n".join(checksums) + "\n")
    with zipfile.ZipFile(PACKAGE_PATH) as archive:
        if archive.testzip() is not None:
            raise ValueError("Falha na verificação de integridade do ZIP.")
        for name in required:
            if "Biblioteca/" + name not in archive.namelist():
                raise ValueError(f"Arquivo obrigatório não foi incluído: {name}")
    digest = hashlib.sha256(PACKAGE_PATH.read_bytes()).hexdigest()
    PACKAGE_PATH.with_suffix(".zip.sha256").write_text(f"{digest}  {PACKAGE_PATH.name}\n", encoding="utf-8")
    print(f"ZIP: {PACKAGE_PATH.relative_to(ROOT)} ({len(files)} arquivos; {PACKAGE_PATH.stat().st_size / 1024 ** 2:.1f} MB)")
    print(f"SHA-256: {digest}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--pdf-only", action="store_true")
    mode.add_argument("--package-only", action="store_true")
    options = parser.parse_args()
    if not options.package_only:
        make_pdf()
    if not options.pdf_only:
        make_package()
