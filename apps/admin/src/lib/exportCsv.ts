/**
 * Utility to export aggregated table data as a downloadable CSV file.
 */
export function exportToCsv(filename: string, rows: Record<string, any>[], headers?: Record<string, string>) {
  if (!rows || !rows.length) return

  const keys = Object.keys(headers || rows[0])
  const headerRow = keys.map((key) => `"${(headers ? headers[key] : key).replace(/"/g, '""')}"`).join(',')

  const csvRows = rows.map((row) => {
    return keys
      .map((key) => {
        const val = row[key] ?? ''
        return `"${String(val).replace(/"/g, '""')}"`
      })
      .join(',')
  })

  const csvContent = [headerRow, ...csvRows].join('\n')
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)

  const link = document.createElement('a')
  link.setAttribute('href', url)
  link.setAttribute('download', filename.endsWith('.csv') ? filename : `${filename}.csv`)
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}
