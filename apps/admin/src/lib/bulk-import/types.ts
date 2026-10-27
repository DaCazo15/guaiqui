export type BulkImportType =
  | 'trivias'
  | 'players'
  | 'staff'
  | 'games'
  | 'products'
  | 'who_is'
  | 'polls'
  | 'over_under'
  | 'mystery_plays'
  | 'score_predictions'
  | 'flash_trivia'
  | 'progressive_clues'

export interface BulkColumnDef {
  key: string
  label: string
  required?: boolean
  description?: string
  example?: string | number
}

export interface BulkImportConfig {
  type: BulkImportType
  title: string
  entityName: string
  templateFileName: string
  columns: BulkColumnDef[]
  sampleData: Record<string, any>[]
  validateRow: (row: Record<string, any>, rowIndex: number) => { valid: boolean; errors: string[] }
  processRows: (rows: Record<string, any>[], supabase: any) => Promise<{ successCount: number; message: string }>
}
