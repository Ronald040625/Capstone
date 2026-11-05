from io import BytesIO

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


def build_pdf_report(
    title: str,
    scope: str,
    generated_at: str,
    headers: list[str],
    rows: list[list[object]],
) -> bytes:
    output = BytesIO()
    document = SimpleDocTemplate(
        output,
        pagesize=landscape(A4),
        leftMargin=1.2 * cm,
        rightMargin=1.2 * cm,
        topMargin=1.2 * cm,
        bottomMargin=1.2 * cm,
    )
    styles = getSampleStyleSheet()
    story = [
        Paragraph(title, styles["Title"]),
        Paragraph(f"Alcance: {scope}", styles["Normal"]),
        Paragraph(f"Generado: {generated_at}", styles["Normal"]),
        Spacer(1, 0.5 * cm),
    ]
    data = [headers, *[[str(value) for value in row] for row in rows]]
    table = Table(data, repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2563EB")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F1F5F9")]),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(table)
    document.build(story)
    return output.getvalue()


def build_excel_report(
    title: str,
    scope: str,
    generated_at: str,
    headers: list[str],
    rows: list[list[object]],
) -> bytes:
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Reporte"
    sheet.append([title])
    sheet.append(["Alcance", scope])
    sheet.append(["Generado", generated_at])
    sheet.append([])
    sheet.append(headers)
    for row in rows:
        sheet.append(row)

    sheet["A1"].font = Font(size=16, bold=True)
    for cell in sheet[5]:
        cell.font = Font(color="FFFFFF", bold=True)
        cell.fill = PatternFill("solid", fgColor="2563EB")
    sheet.freeze_panes = "A6"
    sheet.auto_filter.ref = f"A5:{sheet.cell(5, len(headers)).coordinate}"
    for column in sheet.columns:
        width = max(len(str(cell.value or "")) for cell in column) + 2
        sheet.column_dimensions[column[0].column_letter].width = min(max(width, 12), 35)

    output = BytesIO()
    workbook.save(output)
    return output.getvalue()
