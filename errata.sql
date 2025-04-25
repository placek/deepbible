-- KNOWN BUGS

-- the <> tags
UPDATE grc._all_verses
  SET text = REPLACE(text, '<>', '')
  WHERE id = 'grc/47/140/5/9';
UPDATE grc._all_verses
  SET text = REPLACE(text, '<>', '')
  WHERE id = 'grc/7/490/5/24';

-- wierd tagging in grc/47/350/7/1
UPDATE grc._all_verses
  SET text = REPLACE(text, '<x><E>Israel.<e><q>', '')
  WHERE id = 'grc/47/350/7/1';
UPDATE grc._all_verses
  SET text = REPLACE(text, '<Q>><G>Ισραηλ<g><X>', '')
  WHERE id = 'grc/47/350/7/1';

-- unnecessary <div>, <small>, <b> and <e> tags
UPDATE grc._all_verses
  SET text = regexp_replace(text, '<[^>]*div[^>]*>', '', 'g')
  WHERE text ~ '</?div';

UPDATE pl._all_verses
  SET text = regexp_replace(text, '</?b>', '', 'g')
  WHERE text ~ '</?b>';

UPDATE pl._all_verses
  SET text = regexp_replace(text, '</?e>', '', 'g')
  WHERE text ~ '</?e>';

UPDATE grc._all_verses
  SET text = regexp_replace(text, '</?e>', '', 'g')
  WHERE text ~ '</?e>';

UPDATE grc._all_verses
  SET text = regexp_replace(text, '</?small[^>]*>', '', 'g')
  WHERE text ~ '</?small';

-- remove wierd LXX references
UPDATE grc._all_verses
  SET text = regexp_replace(text, '</?LXX[^>]*>', '', 'g')
  WHERE text ~ '</?LXX';

-- unknown <WW> tag
UPDATE grc._all_verses
  SET text = REPLACE(text, '<WW>', '');

-- wierd references in pl/18
UPDATE pl._all_verses
SET text = regexp_replace(text, '\s*\([^)]*\)', '', 'g')
WHERE source_number = '18' AND text ~ '\(.*\)';

-- broken <S> tags with 0
UPDATE grc._all_verses
  SET text = REPLACE(text, '<S>0</S>', '');
UPDATE pl._all_verses
  SET text = REPLACE(text, '<S>0</S>', '');

-- broken <S> tag in grc/47/110/2/35
UPDATE grc._all_verses
  SET text = REPLACE(text, '<S0</S>', '')
  WHERE id = 'grc/47/110/2/35';

-- broken <S> tag in grc/47/140/5/9
UPDATE grc._all_verses
  SET text = REPLACE(text, '0</S>', '')
  WHERE id = 'grc/47/140/5/9';

-- unknown <W tag in grc/47/230/43/3
UPDATE grc._all_verses
  SET text = REPLACE(text, '<W', '')
  WHERE id = 'grc/47/230/43/3';

-- replace <CM> with <n>
UPDATE pl._all_verses
SET text = regexp_replace(text, '<CM>', '<n>', '') || '</n>'
WHERE text LIKE '%<CM>%';

-- non tags in pl/12/470/18/11
UPDATE pl._all_verses
  SET text = REPLACE(text, '<Albowiem', '[Albowiem')
  WHERE id = 'pl/12/470/18/11';
UPDATE pl._all_verses
  SET text = REPLACE(text, 'zginęło>', 'zginęło]')
  WHERE id = 'pl/12/470/18/11';

-- non tags in pl/19/550/2/7
UPDATE pl._all_verses
  SET text = REPLACE(text, '<apostolstwo>', '[apostolstwo]')
  WHERE id = 'pl/19/550/2/7';

-- non tags in pl/12/470/6/33
UPDATE pl._all_verses
  SET text = REPLACE(text, '<Boga>', '[Boga]')
  WHERE id = 'pl/12/470/6/33';

-- non tags in pl/12/480/7/8
UPDATE pl._all_verses
  SET text = REPLACE(text, '<dokonujecie', '[dokonujecie')
  WHERE id = 'pl/12/480/7/8';
UPDATE pl._all_verses
  SET text = REPLACE(text, 'czynicie>', 'czynicie]')
  WHERE id = 'pl/12/480/7/8';

-- non tags in pl/12/490/13/35
UPDATE pl._all_verses
  SET text = REPLACE(text, '<nadejdzie', '[nadejdzie')
  WHERE id = 'pl/12/490/13/35';
UPDATE pl._all_verses
  SET text = REPLACE(text, 'gdy>', 'gdy]')
  WHERE id = 'pl/12/490/13/35';

-- non tags in pl/12/730/16/15
UPDATE pl._all_verses
  SET text = REPLACE(text, '<Oto', '[Oto')
  WHERE id = 'pl/12/730/16/15';
UPDATE pl._all_verses
  SET text = REPLACE(text, 'widziano>', 'widziano]')
  WHERE id = 'pl/12/730/16/15';

-- non tags in pl/5/290/23/10
UPDATE pl._all_verses
  SET text = REPLACE(text, '<jak', '[jak')
  WHERE id = 'pl/5/290/23/10';
UPDATE pl._all_verses
  SET text = REPLACE(text, 'Nilem>', 'Nilem]')
  WHERE id = 'pl/5/290/23/10';

-- non tags in pl/5/290/59/17
UPDATE pl._all_verses
  SET text = REPLACE(text, '<jak odzienie>', '[jak odzienie]')
  WHERE id = 'pl/5/290/59/17';

-- non tags in pl/12/490/10/42
UPDATE pl._all_verses
  SET text = REPLACE(text, '<mało albo>', '[mało albo]')
  WHERE id = 'pl/12/490/10/42';

-- non tags in pl/12/500/10/13
UPDATE pl._all_verses
  SET text = REPLACE(text, '<najemnik ucieka>', '[najemnik ucieka]')
  WHERE id = 'pl/12/500/10/13';

-- non tags in pl/12/470/18/15
UPDATE pl._all_verses
  SET text = REPLACE(text, '<przeciw tobie>', '[przeciw tobie]')
  WHERE id = 'pl/12/470/18/15';

-- non tags in pl/5/640/1/12
UPDATE pl._all_verses
  SET text = REPLACE(text, '<ty zaś>', '[ty zaś]')
  WHERE id = 'pl/5/640/1/12';
UPDATE pl._all_verses
  SET text = REPLACE(text, '<przyjmij do domu>', '[przyjmij do domu]')
  WHERE id = 'pl/5/640/1/12';

-- non tags in pl/5/290/40/7
UPDATE pl._all_verses
  SET text = REPLACE(text, '<Rzeczywiście trawą jest naród>', '[Rzeczywiście trawą jest naród]')
  WHERE id = 'pl/5/290/40/7';

-- non tags in pl/5/290/28/1
UPDATE pl._all_verses
  SET text = REPLACE(text, '<urodzajnej doliny>', '[urodzajnej doliny]')
  WHERE id = 'pl/5/290/28/1';

-- non tags in pl/12/480/10/24
UPDATE pl._all_verses
  SET text = REPLACE(text, '<tym', '[tym')
  WHERE id = 'pl/12/480/10/24';
UPDATE pl._all_verses
  SET text = REPLACE(text, 'ufność>', 'ufność]')
  WHERE id = 'pl/12/480/10/24';

-- non tags in pl/5/290/22/14
UPDATE pl._all_verses
  SET text = REPLACE(text, '<mówi', '[mówi')
  WHERE id = 'pl/5/290/22/14';
UPDATE pl._all_verses
  SET text = REPLACE(text, 'Zastępów>', 'Zastępów]')
  WHERE id = 'pl/5/290/22/14';

-- non tags in pl/12/500/6/47
UPDATE pl._all_verses
  SET text = REPLACE(text, '<we Mnie>', '[we Mnie]')
  WHERE id = 'pl/12/500/6/47';

-- non tags in pl/5/290/32/19
UPDATE pl._all_verses
  SET text = REPLACE(text, '<Grad', '[Grad')
  WHERE id = 'pl/5/290/32/19';
UPDATE pl._all_verses
  SET text = REPLACE(text, 'nizinom>', 'nizinom]')
  WHERE id = 'pl/5/290/32/19';

-- non tags in pl/5/290/36/11
UPDATE pl._all_verses
  SET text = REPLACE(text, '<Szebna i Joach>', '[Szebna i Joach]')
  WHERE id = 'pl/5/290/36/11';
