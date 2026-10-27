/**
 * Configuración modularizada de importación masiva de datos (Excel / CSV)
 */
import type { BulkImportType, BulkImportConfig, BulkColumnDef } from './bulk-import/types'
import { playerBulkConfig } from './bulk-import/playerImports'
import { staffBulkConfig } from './bulk-import/staffImports'
import { gamesBulkConfig } from './bulk-import/gameImports'
import { productsBulkConfig } from './bulk-import/storeImports'
import {
  triviasBulkConfig,
  whoIsBulkConfig,
  flashTriviaBulkConfig,
  progressiveCluesBulkConfig
} from './bulk-import/triviaImports'
import {
  pollsBulkConfig,
  overUnderBulkConfig,
  mysteryPlaysBulkConfig,
  scorePredictionsBulkConfig
} from './bulk-import/predictionImports'

// Re-export types
export type { BulkImportType, BulkImportConfig, BulkColumnDef }

import { downloadTemplate as rawDownloadTemplate, parseSpreadsheetFile } from './bulk-import/fileParser'

// Re-export parser & download functions
export { parseSpreadsheetFile }
export function downloadTemplate(type: BulkImportType, format: 'xlsx' | 'csv') {
  return rawDownloadTemplate(type, format, BULK_CONFIGS)
}

// Re-export helper functions
export {
  parseBoolean,
  parseDateToISO,
  normalizeGroupCategory,
  normalizeGameStatus,
  normalizeProductCategory,
  normalizeChallengeType
} from './bulk-import/helpers'

// Assembled configs dictionary
export const BULK_CONFIGS: Record<BulkImportType, BulkImportConfig> = {
  trivias: triviasBulkConfig,
  players: playerBulkConfig,
  staff: staffBulkConfig,
  games: gamesBulkConfig,
  products: productsBulkConfig,
  who_is: whoIsBulkConfig,
  polls: pollsBulkConfig,
  over_under: overUnderBulkConfig,
  mystery_plays: mysteryPlaysBulkConfig,
  score_predictions: scorePredictionsBulkConfig,
  flash_trivia: flashTriviaBulkConfig,
  progressive_clues: progressiveCluesBulkConfig
}
