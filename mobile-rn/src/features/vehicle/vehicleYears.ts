/** Selectable years follow the device calendar; existing out-of-range data stays explicit. */
export function modelYearItems(
  storedYear?: number,
  currentYear = new Date().getFullYear(),
) {
  const years = Array.from({ length: currentYear - 1950 + 1 }, (_, index) => ({
    value: String(currentYear - index),
    title: String(currentYear - index),
  }));
  if (
    Number.isInteger(storedYear) &&
    !years.some((item) => item.value === String(storedYear))
  )
    years.push({
      value: String(storedYear),
      title: String(storedYear) + ' (kayıtlı değer)',
    });
  return years;
}

export function validModelYear(value: string, storedYear?: number) {
  if (Number.isInteger(storedYear) && value === String(storedYear)) return true;
  // Retain the existing validation; the new selector only offers through this year.
  return (
    /^\d{4}$/.test(value) &&
    Number(value) >= 1950 &&
    Number(value) <= new Date().getFullYear() + 1
  );
}
