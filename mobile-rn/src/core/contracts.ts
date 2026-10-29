export type Workspace = 'PERSONAL' | 'BUSINESS';

export interface BusinessAccount {
  id: number;
  companyName: string;
  role: 'OWNER' | 'MEMBER';
  sandbox: boolean;
  workspaceAvailable: boolean;
  workspaceAccessStatus: string;
}

export interface UserProfile {
  id: number;
  fullName: string;
  email: string;
  subscriptionPlan: string;
  businessAccount: BusinessAccount | null;
}

export interface AuthResponse extends Omit<UserProfile, 'id'> {
  userId: number;
  accessToken: string;
  tokenType: string;
  expiresIn: number;
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function parseProfile(value: unknown, login = false): UserProfile {
  if (!isRecord(value)) throw new Error('Kullanıcı bilgileri alınamadı.');
  const id = login ? value.userId : value.id;
  if (
    !Number.isSafeInteger(id) ||
    (id as number) <= 0 ||
    typeof value.fullName !== 'string' ||
    typeof value.email !== 'string' ||
    typeof value.subscriptionPlan !== 'string'
  ) {
    throw new Error('Sunucudan geçersiz kullanıcı bilgisi alındı.');
  }
  let businessAccount: BusinessAccount | null = null;
  const business = value.businessAccount;
  if (isRecord(business)) {
    if (
      !Number.isSafeInteger(business.id) ||
      (business.id as number) <= 0 ||
      typeof business.companyName !== 'string' ||
      (business.role !== 'OWNER' && business.role !== 'MEMBER')
    ) {
      throw new Error('Sunucudan geçersiz şirket bilgisi alındı.');
    }
    businessAccount = {
      id: business.id as number,
      companyName: business.companyName,
      role: business.role,
      sandbox: business.sandbox === true,
      workspaceAvailable:
        business.workspaceAvailable === true &&
        business.workspaceAccessStatus === 'ACTIVE',
      workspaceAccessStatus:
        typeof business.workspaceAccessStatus === 'string'
          ? business.workspaceAccessStatus
          : 'UNKNOWN',
    };
  }
  return {
    id: id as number,
    fullName: value.fullName,
    email: value.email,
    subscriptionPlan: value.subscriptionPlan,
    businessAccount,
  };
}
