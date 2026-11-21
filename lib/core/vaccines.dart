class Vaccine {
  final String key;
  final String name;
  final int ageWeeks;
  final String ageLabel;
  const Vaccine(this.key, this.name, this.ageWeeks, this.ageLabel);
}

/// Nigeria routine immunisation schedule (NPI). Always confirm with the clinic card.
const vaccineSchedule = <Vaccine>[
  Vaccine('bcg', 'BCG', 0, 'At birth'),
  Vaccine('opv0', 'OPV 0 (oral polio)', 0, 'At birth'),
  Vaccine('hepb0', 'Hepatitis B 0', 0, 'At birth'),
  Vaccine('penta1', 'Pentavalent 1', 6, '6 weeks'),
  Vaccine('pcv1', 'PCV 1 (pneumococcal)', 6, '6 weeks'),
  Vaccine('opv1', 'OPV 1', 6, '6 weeks'),
  Vaccine('rota1', 'Rotavirus 1', 6, '6 weeks'),
  Vaccine('ipv1', 'IPV 1 (injected polio)', 6, '6 weeks'),
  Vaccine('penta2', 'Pentavalent 2', 10, '10 weeks'),
  Vaccine('pcv2', 'PCV 2', 10, '10 weeks'),
  Vaccine('opv2', 'OPV 2', 10, '10 weeks'),
  Vaccine('rota2', 'Rotavirus 2', 10, '10 weeks'),
  Vaccine('penta3', 'Pentavalent 3', 14, '14 weeks'),
  Vaccine('pcv3', 'PCV 3', 14, '14 weeks'),
  Vaccine('opv3', 'OPV 3', 14, '14 weeks'),
  Vaccine('ipv2', 'IPV 2', 14, '14 weeks'),
  Vaccine('vita1', 'Vitamin A (1st dose)', 26, '6 months'),
  Vaccine('measles1', 'Measles 1', 39, '9 months'),
  Vaccine('yf', 'Yellow Fever', 39, '9 months'),
  Vaccine('mena', 'Meningitis A', 39, '9 months'),
  Vaccine('measles2', 'Measles 2', 65, '15 months'),
];
