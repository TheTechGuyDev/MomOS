// Nigerian dishes for the meal timetable. `wiki` is the Wikipedia article used for the photo.

class Dish {
  final String key;
  final String name;
  final String emoji;
  final String wiki;
  final Set<String> slots; // b = breakfast, l = lunch, d = dinner
  final int minutes;
  final Set<String> tags; // quick, budget, kids, nursing, protein, swallow, light
  final List<String> ingredients;
  final List<String> steps;
  const Dish(this.key, this.name, this.emoji, this.wiki, this.slots, this.minutes, this.tags, this.ingredients, this.steps);
}

const tagLabels = {
  'quick': '⚡ Quick',
  'budget': '💰 Budget',
  'kids': '👧 Kid-friendly',
  'nursing': '🤱 Good for nursing mums',
  'protein': '💪 Protein-rich',
  'swallow': '🍲 Soup & swallow',
  'light': '🌿 Light',
};

const dishes = <Dish>[
  // ---------- Breakfast ----------
  Dish('akara_pap', 'Akara & Pap', '🧆', 'Akara', {'b'}, 40, {'protein', 'kids', 'nursing'},
      ['2 cups beans (peeled)', '1 onion', '1–2 scotch bonnet peppers', 'Salt', 'Vegetable oil for frying', 'Pap (ogi), milk and sugar'],
      ['Soak beans, rub off the skins and rinse well.', 'Blend with onion and pepper using very little water.', 'Whisk the paste until fluffy, then add salt.', 'Fry spoonfuls in hot oil until golden.', 'Mix pap with a little cold water, then stir in boiling water until it thickens. Add milk and sugar.']),
  Dish('moimoi_custard', 'Moi Moi & Custard', '🫔', 'Moin moin', {'b', 'l'}, 75, {'protein', 'kids'},
      ['2 cups peeled beans', '1 red bell pepper (tatashe)', '1 onion', '3 tbsp vegetable oil', '2 boiled eggs (optional)', 'Seasoning cubes and salt', 'Custard powder, milk, sugar'],
      ['Blend peeled beans with pepper and onion until smooth.', 'Stir in oil, seasoning, salt and a little warm water.', 'Pour into tins, bowls or leaves, add egg slices.', 'Steam for 45–60 minutes until firm.', 'Make custard with hot water and serve together.']),
  Dish('yam_egg', 'Yam & Egg Sauce', '🍳', 'Yam (vegetable)', {'b'}, 30, {'quick', 'kids', 'protein'},
      ['Half tuber of yam', '4 eggs', '2 tomatoes', '1 onion', '1 scotch bonnet pepper', 'Oil, salt, seasoning'],
      ['Peel, slice and boil yam with a little salt until soft (15–20 min).', 'Fry chopped onion, tomato and pepper in oil for 5 minutes.', 'Pour in beaten eggs with seasoning and scramble gently.', 'Serve the egg sauce on the yam.']),
  Dish('bread_tea', 'Agege Bread & Tea', '🍞', 'Agege bread', {'b'}, 10, {'quick', 'budget'},
      ['Agege bread', 'Butter or margarine', 'Tea bag or cocoa drink', 'Milk and sugar', 'Fried egg (optional)'],
      ['Slice and lightly toast the bread.', 'Spread butter.', 'Make tea or a cocoa drink with milk.', 'Add a fried egg for extra protein.']),
  Dish('puff_puff', 'Puff-Puff', '🍩', 'Puff-puff', {'b'}, 60, {'kids', 'budget'},
      ['3 cups flour', '1 tbsp yeast', '½ cup sugar', '1½ cups warm water', 'Pinch of salt and nutmeg', 'Oil for frying'],
      ['Mix flour, sugar, yeast, salt and nutmeg.', 'Add warm water and mix into a smooth, sticky batter.', 'Cover and leave to rise for 45 minutes.', 'Scoop small balls into hot oil and fry until golden.', 'Drain on paper towels.']),
  Dish('dodo_egg', 'Dodo & Eggs', '🍌', 'Fried plantain', {'b', 'l'}, 20, {'quick', 'kids'},
      ['2 ripe plantains', '3 eggs', '1 tomato', '½ onion', 'Oil, salt'],
      ['Peel and slice plantains diagonally, add a pinch of salt.', 'Fry in hot oil until golden on both sides.', 'Fry onion and tomato, add beaten eggs and scramble.', 'Serve together.']),
  Dish('bread_beans', 'Bread & Ewa Agoyin', '🫘', 'Ewa agoyin', {'b', 'l'}, 90, {'protein', 'budget', 'nursing'},
      ['2 cups honey beans', 'Palm oil', '6 dried red peppers (tatase/shombo)', '2 onions', 'Crayfish, salt, seasoning', 'Agege bread'],
      ['Cook beans until very soft, then mash lightly with salt.', 'Blend dried peppers and onion coarsely.', 'Bleach palm oil briefly, fry sliced onion, then the pepper mix for 15–20 minutes.', 'Season with crayfish and salt.', 'Serve the sauce over the beans with bread.']),
  Dish('boli', 'Boli & Groundnut', '🍠', 'Boli (food)', {'b', 'l'}, 30, {'quick', 'budget', 'kids'},
      ['2 ripe plantains', 'Roasted groundnuts', 'Pepper sauce (optional)'],
      ['Peel plantains.', 'Roast on a grill or in the oven, turning, until charred and soft (about 25 minutes).', 'Serve with groundnuts.']),
  Dish('oat_pap', 'Pap with Milk & Groundnut', '🥣', 'Ogi (food)', {'b'}, 10, {'quick', 'nursing', 'light', 'kids'},
      ['Pap (ogi/akamu) paste', 'Boiling water', 'Milk', 'Sugar or honey', 'Groundnuts or a handful of nuts'],
      ['Dissolve pap paste in a little cold water.', 'Pour boiling water while stirring until it thickens.', 'Add milk and sweeten lightly.', 'Serve warm with groundnuts. Warm pap is a favourite for nursing mums.']),

  // ---------- Lunch ----------
  Dish('jollof_chicken', 'Jollof Rice & Chicken', '🍛', 'Jollof rice', {'l', 'd'}, 70, {'kids', 'protein'},
      ['3 cups parboiled rice', '6 tomatoes, 3 tatashe, 2 scotch bonnets, 2 onions (blended)', '3 tbsp tomato paste', 'Chicken pieces', 'Oil, curry, thyme, bay leaf, seasoning, salt'],
      ['Season and cook the chicken; keep the stock. Grill or fry the chicken.', 'Fry onions and tomato paste in oil, add the blended pepper and cook until the oil rises (20 min).', 'Add stock, curry, thyme, bay leaf and seasoning.', 'Add rice, cover tightly and cook on low heat until soft (about 30 min).', 'Serve with the chicken and plantain.']),
  Dish('rice_stew', 'White Rice & Stew', '🍚', 'Stew', {'l', 'd'}, 60, {'kids', 'budget'},
      ['3 cups rice', '6 tomatoes, 3 tatashe, 2 scotch bonnets, 1 onion', 'Beef or chicken', 'Oil, seasoning, thyme, curry, salt'],
      ['Cook the meat with onion and seasoning; keep the stock.', 'Blend and boil the pepper mix to reduce water.', 'Fry in oil until sweet and the oil rises (25 min).', 'Add stock and meat; simmer 10 minutes.', 'Boil the rice and serve with the stew.']),
  Dish('rice_efo', 'White Rice & Efo Riro', '🥬', 'Efo riro', {'l', 'd'}, 50, {'nursing', 'protein'},
      ['Rice', '2 bunches spinach (efo tete or shoko)', 'Palm oil', 'Blended tatashe and scotch bonnet', 'Locust beans (iru)', 'Meat, fish, crayfish, seasoning'],
      ['Wash, chop and squeeze the spinach.', 'Heat palm oil, fry onions and iru.', 'Add pepper and cook 15 minutes.', 'Add meat, fish, crayfish and seasoning.', 'Stir in the spinach for 3 minutes. Serve with rice.']),
  Dish('fried_rice', 'Fried Rice & Chicken', '🍤', 'Fried rice', {'l', 'd'}, 60, {'kids', 'protein'},
      ['3 cups parboiled rice', 'Carrots, green beans, sweet corn, green peas', 'Liver (optional)', 'Chicken stock, curry, thyme', 'Spring onions, oil'],
      ['Cook rice in chicken stock with curry and thyme until just done.', 'Stir-fry diced vegetables and liver briefly.', 'Fry the rice in batches with vegetables.', 'Mix together and serve with chicken.']),
  Dish('ofada', 'Ofada Rice & Ayamase', '🌶️', 'Ofada rice', {'l', 'd'}, 90, {'protein'},
      ['Ofada rice', 'Green bell peppers and green scotch bonnets', 'Palm oil (bleached)', 'Locust beans (iru)', 'Assorted meat, boiled eggs'],
      ['Wash ofada rice well and boil until soft.', 'Blend green peppers coarsely and boil to dry out.', 'Bleach palm oil, fry onions and iru.', 'Add the pepper, meat and seasoning; fry until rich (30 min).', 'Serve with eggs.']),
  Dish('coconut_rice', 'Coconut Rice', '🥥', 'Coconut rice', {'l', 'd'}, 50, {'kids'},
      ['3 cups rice', '2 cups coconut milk', 'Tomato paste, onion, pepper', 'Crayfish, seasoning', 'Shrimp or chicken'],
      ['Fry onion, pepper and a little tomato paste.', 'Add coconut milk, crayfish and seasoning.', 'Add parboiled rice and cook covered on low heat.', 'Serve with shrimp or chicken.']),
  Dish('yam_porridge', 'Yam Porridge (Asaro)', '🍠', 'Asaro (food)', {'l', 'd'}, 40, {'budget', 'nursing', 'kids'},
      ['Half tuber of yam', 'Palm oil', 'Blended pepper and onion', 'Crayfish, dry fish', 'Spinach or ugu leaves', 'Seasoning, salt'],
      ['Cube the yam and cook with water, pepper and onion.', 'Add palm oil, crayfish and fish.', 'Mash some yam to thicken.', 'Stir in the leaves and cook 3 more minutes.']),
  Dish('beans_porridge', 'Beans & Plantain Porridge', '🫘', 'Ewa riro', {'l', 'd'}, 80, {'protein', 'budget', 'nursing'},
      ['2 cups beans', '2 ripe plantains', 'Palm oil', 'Blended pepper and onion', 'Crayfish, seasoning'],
      ['Cook beans until soft (pressure pot saves time).', 'Add pepper, onion, palm oil and crayfish.', 'Add sliced plantain and cook 10 more minutes.', 'Mash a little to thicken.']),
  Dish('spag_jollof', 'Jollof Spaghetti & Chicken', '🍝', 'Spaghetti', {'l', 'd'}, 35, {'quick', 'kids'},
      ['500g spaghetti', 'Blended tomato and pepper', 'Tomato paste', 'Chicken stock', 'Onion, curry, seasoning'],
      ['Fry onion and tomato paste, add the pepper and cook down.', 'Add stock and seasoning; bring to the boil.', 'Break in spaghetti and cook until the sauce is absorbed.', 'Serve with chicken.']),

  // ---------- Dinner (soups & swallow, light meals) ----------
  Dish('egusi_py', 'Egusi Soup & Pounded Yam', '🥣', 'Egusi', {'d', 'l'}, 60, {'swallow', 'protein', 'nursing'},
      ['2 cups ground egusi', 'Palm oil', 'Assorted meat and stockfish', 'Crayfish, pepper, seasoning', 'Ugu or bitterleaf', 'Yam for pounded yam'],
      ['Cook the meat and stockfish with seasoning.', 'Fry egusi paste in palm oil until it forms lumps.', 'Add stock, meat, pepper and crayfish; simmer 15 minutes.', 'Add leaves and cook 5 minutes.', 'Boil yam and pound (or use yam flour) until smooth.']),
  Dish('ogbono_fufu', 'Ogbono Soup & Fufu', '🍲', 'Ogbono soup', {'d'}, 50, {'swallow', 'protein'},
      ['1 cup ground ogbono', 'Palm oil', 'Meat, fish, stockfish', 'Crayfish, pepper, seasoning', 'Ugu leaves', 'Fufu'],
      ['Cook meat and fish with seasoning.', 'Dissolve ogbono in warm palm oil.', 'Add stock gradually, stirring until it draws.', 'Add pepper, crayfish and leaves.', 'Serve with fufu.']),
  Dish('okra_fufu', 'Okra Soup & Fufu', '🥒', 'Okra soup', {'d'}, 40, {'swallow', 'nursing', 'quick'},
      ['20 fresh okra, chopped or grated', 'Palm oil', 'Fish, meat, crayfish', 'Ugu leaves', 'Pepper, seasoning', 'Fufu or eba'],
      ['Cook meat and fish with seasoning.', 'Add palm oil, pepper and crayfish.', 'Add okra and cook for 5 minutes only, so it stays green.', 'Add ugu and serve with fufu.']),
  Dish('pepper_soup', 'Pepper Soup & Yam', '🍵', 'Pepper soup', {'d', 'l'}, 45, {'nursing', 'light', 'protein'},
      ['Goat meat, catfish or chicken', 'Pepper soup spice', 'Scent leaf (efirin) or uziza', 'Scotch bonnet, onion', 'Seasoning, salt', 'Boiled yam (optional)'],
      ['Wash the meat or fish and cook with onion and seasoning.', 'Add water, pepper soup spice and pepper.', 'Simmer until tender (fish needs about 10 minutes).', 'Add scent leaves at the end. Traditional after childbirth.']),
  Dish('amala_ewedu', 'Amala, Ewedu & Gbegiri', '🟤', 'Amala (food)', {'d'}, 60, {'swallow', 'nursing'},
      ['Yam flour (elubo)', 'Ewedu leaves', 'Peeled beans for gbegiri', 'Stew', 'Locust beans, potash (small pinch)'],
      ['Boil the ewedu with a pinch of potash and iru, then whisk until smooth.', 'Cook peeled beans until very soft and mash with palm oil and pepper for gbegiri.', 'Stir yam flour into boiling water until smooth for amala.', 'Serve with all three and stew.']),
  Dish('edikang', 'Edikang Ikong & Eba', '🥗', 'Edikang ikong', {'d'}, 60, {'swallow', 'nursing', 'protein'},
      ['Ugu (pumpkin leaves) and waterleaf', 'Palm oil', 'Periwinkle, meat, stockfish, dry fish', 'Crayfish, pepper, seasoning', 'Garri for eba'],
      ['Cook meat, stockfish and fish with seasoning.', 'Add waterleaf and cook down.', 'Add palm oil, pepper, crayfish and periwinkle.', 'Add ugu and cook 5 minutes.', 'Make eba with garri and hot water.']),
  Dish('banga', 'Banga Soup & Starch', '🌴', 'Banga soup', {'d'}, 70, {'swallow'},
      ['Palm fruit concentrate', 'Fresh fish or meat', 'Banga spice, beletete leaves', 'Pepper, crayfish, seasoning', 'Starch or eba'],
      ['Boil palm fruit concentrate with water.', 'Add meat and fish; cook 20 minutes.', 'Add pepper, crayfish and banga spice.', 'Simmer until it thickens. Serve with starch or eba.']),
  Dish('afang', 'Afang Soup & Fufu', '🍃', 'Afang soup', {'d'}, 60, {'swallow', 'protein'},
      ['Ground afang (okazi) leaves', 'Waterleaf', 'Palm oil', 'Meat, periwinkle, stockfish', 'Crayfish, pepper'],
      ['Cook the meat with seasoning.', 'Add waterleaf and palm oil.', 'Add pepper, crayfish and periwinkle.', 'Stir in afang leaves and cook 5 minutes.']),
  Dish('nsala', 'Ofe Nsala (White Soup)', '🐟', 'Nsala soup', {'d'}, 45, {'swallow', 'nursing'},
      ['Catfish or chicken', 'Yam (to thicken)', 'Utazi leaves', 'Ogiri, crayfish, pepper', 'Uda spice'],
      ['Cook fish or chicken with seasoning.', 'Pound a little boiled yam and add to thicken.', 'Add pepper, crayfish, ogiri and uda.', 'Add a few utazi leaves. Popular for new mums.']),
  Dish('tuwo', 'Tuwo Shinkafa & Miyan Kuka', '⚪', 'Tuwo shinkafa', {'d'}, 60, {'swallow'},
      ['Soft rice (tuwo rice)', 'Kuka (baobab leaf powder)', 'Meat, dawadawa', 'Pepper, onion, seasoning'],
      ['Cook soft rice until mushy, then mash and shape into balls.', 'Cook meat with onion and seasoning.', 'Add dawadawa and pepper.', 'Whisk in kuka powder and simmer 5 minutes.']),
  Dish('suya_night', 'Suya & Salad', '🍢', 'Suya', {'d'}, 40, {'protein', 'light'},
      ['Thinly sliced beef', 'Suya spice (yaji)', 'Groundnut oil', 'Onion, tomato, cabbage'],
      ['Coat beef with suya spice and a little oil.', 'Thread onto skewers.', 'Grill or bake at high heat, turning, for 15–20 minutes.', 'Serve with sliced onion, tomato and cabbage.']),
  Dish('moimoi_dinner', 'Moi Moi & Pap', '🫔', 'Moin moin', {'d'}, 75, {'protein', 'light', 'kids'},
      ['Peeled beans', 'Tatashe and onion', 'Oil, seasoning', 'Pap'],
      ['Blend beans with pepper and onion.', 'Add oil and seasoning.', 'Steam in bowls or leaves for 45–60 minutes.', 'Serve with warm pap for a light dinner.']),
  Dish('abacha', 'Abacha (African Salad)', '🥗', 'Abacha (food)', {'l', 'd'}, 30, {'light', 'quick'},
      ['Dried shredded cassava (abacha)', 'Palm oil and potash (ngu)', 'Ugba (oil bean)', 'Garden egg leaves, onion', 'Pepper, crayfish, fish'],
      ['Soak abacha in warm water briefly and drain.', 'Mix palm oil with dissolved potash until it thickens.', 'Add pepper, crayfish, ugba and fish.', 'Mix in abacha, top with onions and leaves.']),
];

Dish? dishByKey(String k) {
  for (final d in dishes) {
    if (d.key == k) return d;
  }
  return null;
}
