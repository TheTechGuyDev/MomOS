// Fixed safety rules for the symptom checker. These decide urgency; the AI never can.

enum Who { mum, baby, child }

class RedFlag {
  final String key;
  final String question;
  final bool emergency; // true = go to hospital now, false = see a doctor today
  const RedFlag(this.key, this.question, {this.emergency = true});
}

const symptomsFor = <Who, List<String>>{
  Who.mum: [
    'Fever', 'Headache', 'Tiredness or weakness', 'Dizziness', 'Breast pain or lump', 'Heavy bleeding',
    'Tummy pain', 'Pain when urinating', 'Back pain', 'Leg pain or swelling', 'Cough', 'Sore throat',
    'Diarrhoea', 'Vomiting or nausea', 'Low mood or anxiety', 'Trouble sleeping', 'Wound or stitches pain',
    'Rash or itching', 'Body aches',
  ],
  Who.baby: [
    'Fever / hot body', 'Cough', 'Runny or blocked nose', 'Fast or noisy breathing', 'Vomiting', 'Diarrhoea',
    'Poor feeding', 'Rash', 'Diaper rash', 'Crying a lot', 'Yellow skin or eyes', 'Very sleepy',
    'Constipation', 'Sticky eyes', 'Pulling at ear',
  ],
  Who.child: [
    'Fever', 'Cough', 'Runny nose', 'Sore throat', 'Ear pain', 'Tummy ache', 'Vomiting', 'Diarrhoea',
    'Headache', 'Rash', 'Itchy skin', 'Tiredness', 'Not eating', 'Toothache', 'Red eyes',
  ],
};

const redFlagsFor = <Who, List<RedFlag>>{
  Who.mum: [
    RedFlag('bleeding', 'Soaking a pad in an hour or less, or passing large clots'),
    RedFlag('chest', 'Chest pain or struggling to breathe'),
    RedFlag('pre_eclampsia', 'Severe headache with blurred vision, or sudden swelling of the face or hands'),
    RedFlag('dvt', 'Pain, swelling or redness in one leg (calf)'),
    RedFlag('seizure', 'Fainting, a fit (seizure) or confusion'),
    RedFlag('self_harm', 'Thoughts of harming yourself or your baby'),
    RedFlag('infection', 'Fever with smelly discharge or worsening tummy pain', emergency: false),
    RedFlag('mastitis', 'Red, hot, painful area on the breast with fever or chills', emergency: false),
    RedFlag('wound', 'Wound or stitches red, swollen, oozing or opening', emergency: false),
  ],
  Who.baby: [
    RedFlag('breathing', 'Struggling to breathe, very fast breathing, or the chest pulling in'),
    RedFlag('blue', 'Blue or grey lips, tongue or skin'),
    RedFlag('floppy', 'Very sleepy, floppy or hard to wake'),
    RedFlag('seizure', 'A fit (seizure) or stiff, jerking movements'),
    RedFlag('feeding', 'Not feeding at all, or vomiting everything'),
    RedFlag('rash_glass', 'A rash that does not fade when you press a glass on it'),
    RedFlag('dehydration', 'Fewer than 4 wet diapers in 24 hours, dry mouth or a sunken soft spot'),
    RedFlag('cry', 'High-pitched cry or crying that will not settle at all', emergency: false),
    RedFlag('green_vomit', 'Green vomit or blood in poo'),
  ],
  Who.child: [
    RedFlag('breathing', 'Struggling to breathe or breathing very fast'),
    RedFlag('drowsy', 'Very drowsy, confused or hard to wake'),
    RedFlag('neck', 'Stiff neck, or light hurts the eyes'),
    RedFlag('rash_glass', 'A rash that does not fade when you press a glass on it'),
    RedFlag('seizure', 'A fit (seizure)'),
    RedFlag('fluids', 'Cannot keep fluids down, or no wee for 12 hours'),
    RedFlag('tummy', 'Severe tummy pain, especially on the lower right side', emergency: false),
    RedFlag('blood', 'Blood in vomit, poo or wee', emergency: false),
  ],
};

class Triage {
  final String urgency; // emergency | doctor_today | doctor_soon | self_care
  final List<String> reasons;
  Triage(this.urgency, this.reasons);
}

/// [tempBand]: 0 none/unknown, 1 = 37.5–37.9, 2 = 38–38.9, 3 = 39+
/// [duration]: 0 <1 day, 1 = 1–3 days, 2 = 4–7 days, 3 = over a week
/// [severity]: 0 mild, 1 moderate, 2 severe
Triage decide({
  required Who who,
  required int ageMonths,
  required Set<String> flags,
  required int tempBand,
  required int duration,
  required int severity,
  required Set<String> symptoms,
}) {
  final reasons = <String>[];
  var level = 3; // 0 emergency, 1 today, 2 soon, 3 self-care
  void raise(int l, String why) {
    if (l < level) level = l;
    reasons.add(why);
  }

  for (final f in redFlagsFor[who]!) {
    if (flags.contains(f.key)) raise(f.emergency ? 0 : 1, f.question);
  }

  final fever = tempBand >= 2;
  if (who == Who.baby) {
    if (ageMonths < 3 && fever) raise(0, 'Any fever of 38°C or more in a baby under 3 months needs urgent care');
    if (ageMonths >= 3 && ageMonths < 6 && tempBand >= 3) raise(1, 'Fever of 39°C or more in a baby under 6 months');
    if (fever && duration >= 1) raise(1, 'Fever in a baby lasting more than a day');
    if (symptoms.contains('Yellow skin or eyes') && ageMonths < 1) raise(1, 'Yellow skin or eyes in a newborn should be checked today');
    if (symptoms.contains('Diarrhoea') && symptoms.contains('Vomiting')) raise(1, 'Vomiting and diarrhoea together can dehydrate a baby quickly');
    if (severity >= 2) raise(1, 'You rated it as severe');
  } else {
    if (tempBand >= 3 && duration >= 1) raise(1, 'High fever (39°C or more) for more than a day');
    if (fever && duration >= 2) raise(1, 'Fever lasting more than 3 days');
    if (who == Who.mum && fever && ageMonths <= 2) raise(1, 'Fever in the first weeks after giving birth should be checked today');
    if (severity >= 2) raise(1, 'You rated it as severe');
  }
  if (fever && level > 2) raise(2, 'Fever: get a malaria test (RDT) at a clinic or pharmacy');
  if (duration >= 3) raise(2, 'Symptoms for more than a week');
  if (who == Who.mum && symptoms.contains('Low mood or anxiety') && duration >= 2) {
    raise(2, 'Low mood for more than a few days after birth is common and treatable. Talk to your doctor');
  }
  if (severity == 1 && level > 2 && duration >= 1) raise(2, 'Moderate symptoms for more than a day');

  const names = ['emergency', 'doctor_today', 'doctor_soon', 'self_care'];
  return Triage(names[level], reasons);
}

/// Simple built-in tips used when the AI is unavailable.
const fallbackTips = <String, (List<String>, List<String>)>{
  'Fever': (['Malaria (common in Nigeria, needs a test)', 'A viral infection'], ['Drink plenty of fluids', 'Wear light clothing and rest', 'Get a malaria test at a clinic or pharmacy']),
  'Fever / hot body': (['Malaria (needs a test)', 'A viral infection'], ['Keep breastfeeding or feeding often', 'Dress baby lightly', 'Check the temperature again in an hour']),
  'Cough': (['A cold or viral infection', 'Chest infection if breathing is fast'], ['Fluids and rest', 'Keep away from smoke', 'Raise the head slightly when sleeping']),
  'Diarrhoea': (['Stomach infection (gastroenteritis)', 'Something eaten'], ['Give ORS (oral rehydration salts) in small sips', 'Keep feeding; for babies keep breastfeeding', 'Wash hands well']),
  'Vomiting': (['Stomach bug', 'Food-related'], ['Small sips of ORS or water often', 'Rest the stomach, then bland food']),
  'Headache': (['Tiredness or lack of sleep', 'Not drinking enough', 'Malaria if there is fever'], ['Drink water and rest in a dark room', 'Eat regular meals']),
  'Breast pain or lump': (['Blocked milk duct', 'Mastitis if red and hot'], ['Keep feeding or expressing from that side', 'Warm compress before feeds', 'Gentle massage towards the nipple']),
  'Diaper rash': (['Irritation from wetness'], ['Change diapers often', 'Let the skin air-dry', 'Use a barrier cream']),
  'Runny or blocked nose': (['Common cold'], ['Saline drops before feeds', 'Keep the room airy', 'Feed little and often']),
  'Low mood or anxiety': (['Baby blues or postnatal depression', 'Exhaustion'], ['Talk to someone you trust today', 'Rest when you can and accept help', 'Speak to your doctor; it is treatable']),
};
