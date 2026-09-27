class VehicleCatalog {
  const VehicleCatalog._();

  static const Map<String, List<String>> brandModels = {
    'Alfa Romeo': ['Giulia', 'Giulietta', 'Stelvio', 'Tonale'],
    'Audi': ['A1', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'Q2', 'Q3', 'Q5', 'Q7', 'Q8'],
    'BMW': ['1 Serisi', '2 Serisi', '3 Serisi', '4 Serisi', '5 Serisi', '7 Serisi', 'X1', 'X2', 'X3', 'X4', 'X5', 'X6'],
    'Chery': ['Arrizo 8', 'Omoda 5', 'Tiggo 7 Pro', 'Tiggo 8 Pro'],
    'Citroen': ['C3', 'C3 Aircross', 'C4', 'C4 X', 'C5 Aircross', 'Berlingo'],
    'Dacia': ['Duster', 'Jogger', 'Logan', 'Sandero', 'Sandero Stepway'],
    'Fiat': ['500', '500X', 'Doblo', 'Egea', 'Fiorino', 'Panda', 'Tipo'],
    'Ford': ['Fiesta', 'Focus', 'Kuga', 'Mondeo', 'Mustang', 'Puma', 'Ranger', 'Tourneo Courier'],
    'Honda': ['Accord', 'City', 'Civic', 'CR-V', 'HR-V', 'Jazz'],
    'Hyundai': ['Bayon', 'Elantra', 'i10', 'i20', 'i30', 'Ioniq 5', 'Kona', 'Santa Fe', 'Tucson'],
    'Jeep': ['Avenger', 'Compass', 'Grand Cherokee', 'Renegade', 'Wrangler'],
    'Kia': ['Ceed', 'Cerato', 'EV3', 'EV6', 'Niro', 'Picanto', 'Rio', 'Sportage', 'Stonic'],
    'Mercedes-Benz': ['A Serisi', 'B Serisi', 'C Serisi', 'CLA', 'E Serisi', 'GLA', 'GLB', 'GLC', 'GLE', 'S Serisi'],
    'MG': ['HS', 'MG4', 'MG5', 'ZS'],
    'Mini': ['Cooper', 'Countryman'],
    'Nissan': ['Juke', 'Micra', 'Qashqai', 'X-Trail'],
    'Opel': ['Astra', 'Combo', 'Corsa', 'Crossland', 'Grandland', 'Mokka'],
    'Peugeot': ['2008', '208', '3008', '308', '408', '5008', '508', 'Rifter'],
    'Renault': ['Austral', 'Captur', 'Clio', 'Fluence', 'Kangoo', 'Megane', 'Rafale', 'Symbol'],
    'Seat': ['Arona', 'Ateca', 'Ibiza', 'Leon', 'Tarraco'],
    'Skoda': ['Fabia', 'Kamiq', 'Karoq', 'Kodiaq', 'Octavia', 'Scala', 'Superb'],
    'Suzuki': ['S-Cross', 'Swift', 'Vitara'],
    'Tesla': ['Model 3', 'Model S', 'Model X', 'Model Y'],
    'TOGG': ['T10F', 'T10X'],
    'Toyota': ['C-HR', 'Corolla', 'Corolla Cross', 'Hilux', 'Land Cruiser', 'Proace City', 'RAV4', 'Yaris', 'Yaris Cross'],
    'Volkswagen': ['Amarok', 'Caddy', 'Golf', 'Passat', 'Polo', 'T-Cross', 'T-Roc', 'Taigo', 'Tiguan', 'Touareg'],
    'Volvo': ['EX30', 'S60', 'S90', 'V60', 'XC40', 'XC60', 'XC90'],
  };

  static List<String> get brands => brandModels.keys.toList(growable: false);

  static List<String> modelsFor(String brand) =>
      brandModels[brand] ?? const <String>[];
}
