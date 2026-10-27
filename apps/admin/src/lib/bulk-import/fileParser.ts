import * as XLSX from 'xlsx'
import type { BulkImportConfig, BulkImportType } from './types'

/**
 * Exporta y descarga la plantilla en formato Excel (.xlsx) o CSV (.csv)
 */
export function downloadTemplate(
  type: BulkImportType,
  format: 'xlsx' | 'csv',
  configs: Record<BulkImportType, BulkImportConfig>
) {
  const config = configs[type]
  if (!config) return

  // Create worksheet with sample data
  const ws = XLSX.utils.json_to_sheet(config.sampleData, {
    header: config.columns.map(c => c.key)
  })

  // Set column widths nicely
  ws['!cols'] = config.columns.map(c => ({
    wch: Math.max(c.label.length, c.key.length, 18)
  }))

  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, config.entityName)

  if (format === 'xlsx') {
    XLSX.writeFile(wb, `${config.templateFileName}.xlsx`)
  } else {
    XLSX.writeFile(wb, `${config.templateFileName}.csv`, { bookType: 'csv' })
  }
}

/**
 * Parsea un archivo File (Excel o CSV) y devuelve el array de objetos json
 */
export async function parseSpreadsheetFile(file: File): Promise<Record<string, any>[]> {
  const arrayBuffer = await file.arrayBuffer()
  const wb = XLSX.read(arrayBuffer, {
    type: 'array',
    cellDates: false,
    raw: false
  })

  const firstSheetName = wb.SheetNames[0]
  if (!firstSheetName) return []

  const ws = wb.Sheets[firstSheetName]
  const rawRows: Record<string, any>[] = XLSX.utils.sheet_to_json(ws, {
    raw: false,
    defval: ''
  })

  // Normalizar llaves eliminando espacios, minúsculas y caracteres invisibles
  return rawRows.map(row => {
    const normalized: Record<string, any> = {}
    for (const [key, value] of Object.entries(row)) {
      const cleanKey = key.trim().toLowerCase().replace(/\s+/g, '_')
      normalized[cleanKey] = value
    }
    return normalized
  })
}
