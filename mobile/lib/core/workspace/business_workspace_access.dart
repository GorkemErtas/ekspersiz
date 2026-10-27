String businessWorkspaceAccessMessage(String status) => switch (status) {
  'ACTIVE' => 'Business çalışma alanı aktif.',
  'SUBSCRIPTION_EXPIRED' =>
    'Şirketin Business aboneliği sona erdi. Kişisel hesabınızı kullanmaya devam edebilirsiniz.',
  'SUBSCRIPTION_INACTIVE' => 'Şirketin Business aboneliği aktif değil.',
  'SANDBOX_NOT_AUTHORIZED' => 'Bu şirket için test erişimi yetkilendirilmedi.',
  'ENVIRONMENT_MISMATCH' =>
    'Abonelik bu şirketin çalışma alanında kullanılamıyor.',
  'OWNER_UNAVAILABLE' => 'Şirket sahibinin Business erişimi doğrulanamadı.',
  _ => 'Şirket çalışma alanına erişim doğrulanamadı.',
};
