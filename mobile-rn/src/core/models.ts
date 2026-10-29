export interface Vehicle {
  id: number;
  plate: string;
  brand: string;
  model: string;
  modelYear: number;
  mileage: number;
  primaryVehicle: boolean;
  notes?: string | null;
  createdAt?: string;
}
export interface Maintenance {
  id: number;
  maintenanceType: string;
  maintenanceDate: string;
  mileage: number;
  cost?: number | null;
  note?: string | null;
  nextRecommendedDate?: string | null;
  nextRecommendedMileage?: number | null;
  intervalMonths?: number | null;
  intervalMileage?: number | null;
  createdByName: string;
}
export interface Reminder {
  id: number;
  reminderType: string;
  title?: string | null;
  dueDate?: string | null;
  dueMileage?: number | null;
  note?: string | null;
  status: string;
  daysRemaining?: number | null;
  mileageRemaining?: number | null;
  sourceDate?: string | null;
  sourceMileage?: number | null;
  intervalMonths?: number | null;
  intervalMileage?: number | null;
  firstInspection?: boolean | null;
}
export interface VehicleOverview {
  vehicle: Vehicle;
  trackingStatus: string;
  disclaimer: string;
  latestMaintenance?: Maintenance | null;
  upcomingReminders: Reminder[];
  latestInspectionId?: number | null;
  latestDamageSeverity?: string | null;
  latestInspectionAt?: string | null;
}
export interface HistoryItem {
  type: string;
  title: string;
  description: string;
  occurredAt: string;
}
export interface Finding {
  damageType: string;
  affectedPart: string;
  severity: string;
  description: string;
  repairNotes: string;
  replacementAssessment: string;
}
export interface Recommendation {
  damageType: string;
  recommendedAction: string;
  partReplacementRequired: boolean | null;
  affectedParts: string[];
}
export interface Detection {
  id: number;
  label: string;
  confidence: number;
  affectedPart: string;
  x1: number;
  y1: number;
  x2: number;
  y2: number;
}
export interface InspectionReport {
  title: string;
  summary: string;
  damageDescription: string;
  repairRecommendation: string;
  estimatedMinimumPrice: number;
  estimatedMaximumPrice: number;
  currency: string;
  priceInformation: string;
  priceSourceDescription: string;
  disclaimer: string;
  generatedAt?: string | null;
}
export interface Inspection {
  id: number;
  vehicleId: number;
  vehiclePlate: string;
  vehicleBrand: string;
  vehicleModel: string;
  vehicleModelYear: number;
  vehicleMileage: number;
  userId: number;
  imagePath: string | null;
  contextImagePath?: string | null;
  schemaVersion?: string | null;
  modelVersion?: string | null;
  status: string;
  reportStatus?: string | null;
  reportMessage?: string | null;
  damageSeverity?: string | null;
  damageTypes: string[];
  affectedParts: string[];
  repairRecommendations: Recommendation[];
  confidenceScore?: number | null;
  analysisMessage?: string | null;
  createdAt?: string | null;
  completedAt?: string | null;
  detections: Detection[];
  visualFindings: Finding[];
  report: InspectionReport | null;
  locationCity: string;
  locationLatitude?: number | null;
  locationLongitude?: number | null;
  analysisOutcome?: string | null;
  additionalPhotoGuidance?: string | null;
}
export interface DamageRecord {
  id: number;
  inspectionId: number;
  recordNumber: string;
  status: string;
  documentVersion: number;
  incidentDateTime: string;
  incidentCity: string;
  incidentDistrict?: string | null;
  incidentAddress?: string | null;
  incidentDescription: string;
  declarantFullName: string;
  createdAt?: string | null;
  updatedAt?: string | null;
  finalizedAt?: string | null;
  snapshotJson?: string | null;
  contentHash?: string | null;
}
export interface RecordInput {
  incidentDateTime: string;
  incidentCity: string;
  incidentDistrict: string | null;
  incidentAddress: string | null;
  incidentDescription: string;
  declarantFullName: string;
}
export interface NearbyService {
  placeId: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  rating?: number | null;
  userRatingCount?: number | null;
  primaryType?: string | null;
  googleMapsUri?: string | null;
  distanceKm: number;
}
export interface AppNotification {
  id: number;
  vehicleId?: number | null;
  notificationType: string;
  severity: string;
  title: string;
  body: string;
  navigationTarget?: string | null;
  read: boolean;
  createdAt: string;
}
export interface BusinessMember {
  id: number;
  userId: number;
  fullName: string;
  email: string;
  role: string;
}
export interface Source {
  name: string;
  url?: string | null;
}
export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  sources?: Source[];
}
export interface AssistantEntitlement {
  status: string;
  canAsk: boolean;
  dailyLimit: number;
  usedToday: number;
  remainingToday: number;
  outOfScopeAttemptsToday: number;
  quotaPeriod: string;
  trialExpiresAt?: string | null;
  lockedUntil?: string | null;
}
export interface AssistantReply {
  intent: string;
  answer: string;
  quotaConsumed: boolean;
  remainingToday: number;
  toolsUsed: string[];
  sources: Source[];
}
export interface BillingStatus {
  billingCustomerId: string;
  currentPlan: string;
  status: string;
  productId?: string | null;
  autoRenewing: boolean;
  sandbox: boolean;
  currentPeriodEndsAt?: string | null;
  managementUrl?: string | null;
  lastSyncedAt?: string | null;
  verificationStatus: string;
}
export interface BillingPlan {
  plan: string;
  title: string;
  description: string;
  productId: string | null;
  packageIdentifier: string | null;
  fallbackMonthlyPrice: number;
  currency: string;
  highlighted: boolean;
  features: string[];
}
export interface BillingOverview {
  status: BillingStatus;
  plans: BillingPlan[];
}
export interface CreditProduct {
  productId: string;
  resource: string;
  quantity: number;
  business: boolean;
  referencePrice: number;
}
export interface CreditAccount {
  canPurchase: boolean;
  owner: boolean;
  usedSlots: number;
  totalSlots: number;
  balances: Record<string, { available: number; periodic: number }>;
}
export interface CreditOverview {
  personal: CreditAccount | null;
  company: CreditAccount | null;
  products: CreditProduct[];
}

export function positiveId(value: unknown): number {
  const id =
    typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value;
  if (typeof id !== 'number' || !Number.isSafeInteger(id) || id <= 0)
    throw new Error('Kayıt kimliği geçersiz.');
  return id;
}
export const needsMorePhotos = (inspection: Inspection) =>
  ['NEEDS_MORE_PHOTOS', 'INCONCLUSIVE'].includes(
    inspection.analysisOutcome ?? '',
  );
export const inspectionOnly = (inspection: Inspection) =>
  inspection.schemaVersion === 'hitl-v1' ||
  ((inspection.repairRecommendations ?? []).length > 0 &&
    (inspection.repairRecommendations ?? []).every(
      (r) => r.recommendedAction === 'PROFESSIONAL_INSPECTION',
    ));
