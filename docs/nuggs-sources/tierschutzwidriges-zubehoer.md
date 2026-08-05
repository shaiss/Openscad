# *Tierschutzwidriges Zubehör*

> Full-text Markdown conversion for the NUGGS system. The page-addressable
> transcription follows the NUGGS evidence note.

## Source and conversion

- **Publisher:** Deutscher Tierschutzbund e.V.
- **Edition:** June 2024
- **Original:** [`tierschutzwidriges-zubehoer.pdf`](tierschutzwidriges-zubehoer.pdf)
- **Publisher URL:** <https://www.tierschutzbund.de/fileadmin/Seiten/tierschutzbund.de/Downloads/Berichte/Positionspapier_DTSchB_Tierschutzwidriges_Zubehoer.pdf>
- **NUGGS issue:** [#82](https://github.com/shaiss/print-bench/issues/82)
- **PDF pages:** 12
- **PDF SHA-256:** `eeb0926f786fdf0a90971b9b45f12ef3882a86e96289a3a93c37c1f6265c6da6`

The PDF contains tagged embedded text; this conversion was made from that text,
not OCR. Source page boundaries are retained. Line wraps were joined, bullets
were converted to Markdown lists, and no substantive wording was translated or
rewritten. The PDF remains the authority for typography and pagination.

## NUGGS evidence note

### Primary wording

The relevant bullet begins on PDF page 7 and ends on page 8:

> Röhrensysteme: In senkrechten und stark geneigten Röhren sowie bei Röhren
> mit Öffnungen, die nach unten zeigen besteht Verletzungsgefahr. Lange
> Röhrensysteme können nicht leicht gereinigt werden und sind schlecht
> belüftbar. Es bildet sich Kondenswasser, in welchem sich Krankheitserreger
> vermehren können. Das transparente Material bietet keine Rückzugsmöglichkeit
> für die Tiere. Diese Systeme können das natürliche Grabebedürfnis der Tiere
> nicht befriedigen. Kunststoffröhren sind nur dann akzeptabel, wenn sie
> höchstens die doppelte Körperlänge des Tieres haben, eine ausreichende
> Belüftung gewährleisten und mit einer Gebrauchsanleitung versehen sind, die
> deutlich macht, dass derartige Röhren nicht missbräuchlich verwendet werden
> dürfen. Röhren aus Naturmaterialien (z. B. Sisal, Ton) sind Kunststoffröhren
> vorzuziehen.

### Findings for the product charter

1. **The criterion is per plastic tube, not an explicit total-system sum.**
   `Kunststoffröhren` is the grammatical subject of all three conditions. The
   document separately uses `Röhrensysteme` when discussing long systems but
   states no summed system-length formula.
2. **It is a limit, not a recommendation.** `nur dann akzeptabel, wenn` and
   `höchstens` mean acceptable only if, and at most.
3. **It is conjunctive.** Length, adequate ventilation, and instructions
   against misuse are joined in one `wenn … und …` test.
4. **The source does not define a NUGGS run or break.** NUGGS treats a
   continuously enclosed bore as one plastic tube even when printed components
   are joined by couplings. Run and break are the operational definitions that
   let the design and CI enforce the source's per-tube cap; they do not add a
   stricter cap.
5. **This document contains no 7 cm or 70 mm entrance minimum.** Its page 7
   housing guidance says openings should be sized for the species, without a
   number. The NUGGS bore floor therefore needs a different primary source.
6. **TVT Merkblatt 62 appears only in the source list on page 12.** This paper
   does not map individual sentences to that reference, so it cannot establish
   whether Merkblatt 62 itself contains a numerical length rule.

### Product-manager decision

N2's source-scope question is resolved: remove the provisional per-tube marker.
Keep NUGGS's per-run check as the enforceable definition of one plastic tube
across component joints, and continue to distinguish that operational mapping
from quoted source language. Never cite the 2× condition without its ventilation
and instructions limbs. Keep N1's 70 mm floor as a safety rule, but do not
attribute that number to this position paper.

## Full German transcription

## PDF page 1

Deutscher Tierschutzbund e.V. In der Raste 10 53129 Bonn Tel. 0228 60 49 6-0 Fax 0228 60 49 6-40 bg@tierschutzbund.de www.tierschutzbund.de Stand: 06/2024

### Inhaltsverzeichnis

Rechtliche Lage ...................................................................................................2

Beispiele für tierschutzwidriges Zubehör..............................................................2

Katze ................................................................................................................2

Zubehör.........................................................................................................2

Spielzeug ......................................................................................................3

Hund .................................................................................................................4

Zubehör.........................................................................................................4

Spielzeug ......................................................................................................5

Unterbringung ...............................................................................................6

Sonstiges ......................................................................................................6

Kleine Heimtiere ...............................................................................................6

Zubehör.........................................................................................................6

Spielzeug ......................................................................................................7

Sonstiges ......................................................................................................8

Vögel ................................................................................................................8

Zubehör.........................................................................................................8

Spielzeug ......................................................................................................9

Sonstiges .................................................................................................... 10

Reptilien.......................................................................................................... 10

Zubehör....................................................................................................... 10

Fische............................................................................................................. 11

Zubehör....................................................................................................... 11

Forderung des Deutschen Tierschutzbundes ..................................................... 12

Quellen............................................................................................................... 12



## PDF page 2

### Rechtliche Lage

Nach § 2 Tierschutzgesetz ist jeder, der ein Tier hält, dazu verpflichtet, dieses angemessen zu ernähren, zu pflegen und verhaltensgerecht unterzubringen sowie ihm die Möglichkeit zu artgemäßer Bewegung ausreichend zu gestatten. Dieser Grundsatz sollte sich selbstverständlich auch in der Auswahl des im Handel angebotenen Heimtierzubehörs widerspiegeln.

### Beispiele für tierschutzwidriges Zubehör

### Katze

#### Zubehör

- Katzentoiletten: Bedenklich sind Toiletten mit Deckel, da Belüftungsprobleme entstehen, vor allem, wenn sie noch eine zusätzliche Türklappe enthalten. Auch entspricht der Toilettengang in einer „Höhle“ nicht dem natürlichen Ausscheidungsverhalten von Katzen. In Möbelstücken, wie Schränken oder Regalen, „versteckte“ Toiletten sind ebenfalls keine geeigneten Toiletten für Katzen. Ungeeignetes Toilettenmanagement kann dazu führen, dass die Katze die Toilette nicht mehr oder nur ungern aufsucht. Dies kann auch eine Ursache für Unsauberkeit sein. Katzentoiletten sollten eine Mindestgröße von 60 x 40 Zentimetern haben, damit die Katze sich bequem darin drehen, hinhocken und scharren kann. Die Höhe des Randes der Toilette muss den individuellen Ansprüchen der Katze gerecht werden: vor allem bei älteren Katzen mit orthopädischen Problemen sollte eine niedrige Einstiegshöhe gegeben sein.

- Katzenstreu: Abzulehnen ist Streu mit spitzen oder scharfkantigen Steinchen, stark staubhaltige sowie parfümierte (deodorierte) Einstreu.

- Halsbänder (Flohhalsbänder, Schmuckhalsbänder mit oder ohne Glöckchen): Es besteht die große Gefahr des Hängenbleibens bis zur Erdrosselung durch das Halsband. Des Weiteren besteht die Gefahr, dass die Katze, wenn sie sich putzt, mit einem Vorderlauf durch das Halsband schlüpft und sich in der Folge erhebliche Verletzungen in der Achselhöhle zuzieht. Das Tragen eines Glöckchens zur Warnung von Vögeln ist ohnehin kaum wirksam. Die Katze ist ein Lauer- und Sprungjäger, kein Verfolgungsjäger. Katzen sollten darum kein Halsband tragen, sondern durch einen Transponder mit Mikrochip unverwechselbar gekennzeichnet und bei FINDEFIX, dem Haustierregister des Deutschen Tierschutzbundes, registriert sein.

- Katzenschutznetze: Bei Maschen, die größer als drei mal drei Zentimeter sind, besteht die Gefahr, dass die Katze mit Körperteilen in der Netzmasche hängen bleibt (Gefahr des Erdrosselns). Zu empfehlen ist beispielsweise handelsüblicher „Kaninchendraht“.

- Kippfenster: Können lebensgefährlich sein, wenn sie nicht durch entsprechende Schutzvorrichtungen (erhältlich im Fachhandel) gesichert sind.

- Krallenschutzkappen: Von diversen Anbietern gibt es Krallenschutzkappen aus Plastik, welche nach Kürzen der Krallen durch den Besitzer angeklebt werden sollen, um zu verhindern, dass die Katzen



## PDF page 3

Möbel und Teppiche u.a. durch ihre Krallen zerstören können. Die Unterdrückung des natürlichen Kratz-Verhaltens ist aus Tierschutzsicht abzulehnen. Auch besteht Verletzungsgefahr, da die Plastikkappen abgeknabbert werden können. Auf tierärztliche Empfehlung hin kann ein vorübergehendes Anbringen von Krallenschutzkappen über einen kurzen Zeitraum ausnahmsweise aus medizinischen Gründen sinnvoll sein (z. B. nach Wundversorgung oder einer Operation).

- Katzenkäfige: v.a. auf Onlineplattformen sind häufig verschließbare Käfige oder Ställe für Katzen zu finden, die gerne als Möbelstück verkauft werden oder in ein Möbelstück integriert sind. Auch ein vorübergehendes Einsperren von Katzen in solchen Käfigen ist tierschutzwidrig. Das natürliche Bewegungsverhalten und das Ausleben von natürlichen Verhaltensweisen ist der Katze in diesen engen Räumen nicht möglich. Ausnahmen sind nur medizinische Indikationen (vorübergehende Ruhighaltung) nach tierärztlicher Rücksprache.

- Katzenrucksäcke: Katzenrucksäcke (teilweise mit Bullaugen) werden v.a. verwendet, um die Katze –ähnlich wie einen Hund- mit auf Wanderungen, Spaziergänge etc. mitnehmen zu können. Katzen sind grundsätzlich ortstreue Tiere und ein Transport/Ortswechsel stellt für einen Großteil der Katzen großen Stress dar. Auf längeren Strecken ist fraglich, wie ein guter Luftaustausch in den Rucksäcken gewährleistet werden kann. Zudem besteht beim Öffnen des Rucksacks das Risiko des Entlaufens. Muss eine Katze transportiert werden (z. B. in die Tierarztpraxis), sollte das immer in einer entsprechend sicheren und geeigneten Transportbox nach Gewöhnung des Tieres erfolgen.

- Katzenklammer: Die Katzenklammer wird im Nacken des Tieres befestigt und soll den Nackengriff simulieren, der Katzen in Starre und Todesangst versetzt. Sie soll der Fixation dienen, z. B. bei Pflegemaßnahmen. Katzenklammern sind als absolut tierschutzwidrig einzustufen.

- Kostüme: es gibt keinen vernünftigen Grund Katzen zur reinen Belustigung (z. B. an Fasching) Kostüme anzuziehen oder sie anderweitig zu verkleiden. Dies kann zu Stress und Leiden bei den Katzen führen. Kostüme und Verkleidungen sind daher aus Tierschutzsicht abzulehnen.

- Maulkörbe: Maulkörbe für Katzen sind in verschiedenen Ausführungen im Handel erhältlich. Neben Maulkörben aus Nylon, die zusätzlich die Augen verdecken, existieren noch Masken aus diversen Materialien sowie Helme aus Kunststoff, die den gesamten Kopf umschließen. Der Einsatz von Maulkörben ist grundsätzlich abzulehnen. Insbesondere der langfristige bis dauerhafte Einsatz, um beispielsweise das Ergreifen von Beutetieren oder innerartliche Auseinandersetzungen zu verhindern, ist eindeutig als tierschutzwidrig einzustufen.

#### Spielzeug

- Es besteht Verletzungsgefahr durch Draht-, Glas-, Metall- oder Kunststoffteile in Fell-Spielzeug, durch Spielzeug aus Hartplastik sowie durch Hängenbleiben und Abschnüren von Körperteilen bei Spielzeug, das aufgehängt wird. Hängespielzeug kann unter Aufsicht durchaus Abwechslung bieten, muss aber unbedingt vor Verlassen des Zimmers entfernt werden.

- Kleine Bälle aus Alufolie sowie Schaumstoff- und Styroporbälle können verschluckt werden.



## PDF page 4

Bei größeren Bällen besteht die Gefahr des Verschluckens von abgebissenen Teilen. Zu empfehlen sind z.B. Golfbälle, Squashbälle, aufziehbares Kinderspielzeug aus Metall, Vollgummispielzeug.

- Fellmäuse mit Plastikkern und Augen oder Nasen aus spitzen Kunststoffnägeln können zu schweren inneren Verletzungen führen.

- Laserpointer: Wenn Laserpointer direkt auf die Augen gerichtet werden, können sie dort erhebliche Schäden anrichten. Dies ist beim Menschen wissenschaftlich nachgewiesen. Auf Grund des Risikos, das für Katzen (und Menschen) beim Umgang mit Laserpointern besteht, sollten sie nicht als Spielzeug verwendet werden. Zudem kann es im Spiel mit Laserpointern zur Frustration des Tieres und bei Tieren mit hoher Erregungslage auch zu Verhaltensauffälligkeiten führen.

- Wollknäuel/Nähgarn: Gefahr des Verschluckens, führt im Darm zu schweren Verletzungen (wird messerscharf und kann Darmverschluss hervorrufen).

### Hund

#### Zubehör

Hinweis: Die Anwendung von manchem Hunde- Zubehör ist nach Tierschutz- Hundeverordnung §2 Abs. 5 „verboten, bei der Ausbildung, bei der Erziehung oder beim Training von Hunden Stachelhalsbänder oder andere für die Hunde schmerzhafte Mittel zu verwenden.“ Leider ist es nicht verboten solches Zubehör zu verkaufen (ein Veterinäramt hätte bei einer Kontrolle keine rechtliche Handhabe), hier kann lediglich beim Geschäftsinhaber aufgeklärt (bzw. Online- Händler angeschrieben werden), evtl. geht der Verkäufer darauf ein und nimmt das Produkt aus dem Angebot. Im Zweifelsfall sollte man in diesem Laden nicht mehr selbst einkaufen und auch andere Personen darüber informieren und aufmerksam machen.

- Stachelhalsbänder, Endloswürger, Erziehungsgeschirre mit Zugwirkung unter den Achselhöhlen: Diese Artikel arbeiten auf der Basis von Schmerzen und Verletzungen => Verbot der Anwendung nach Tierschutz- Hundeverordnung.

- Elektroreizgerät, z. B. Teletakt: Im Jahr 2006 hat das Bundesverwaltungsgericht (BVerwG) entschieden, dass der Einsatz von Elektroreizgeräten, die erhebliche Leiden oder Schmerzen verursachen können, bei der Hundeausbildung nach geltendem Tierschutzrecht verboten ist (AZ 3 C 14.05) => Verbot der Anwendung nach § 3 Nr. 11 Tierschutzgesetz und nach Tierschutz-Hundeverordnung.

- "Unsichtbarer Gartenzaun": Systeme arbeiten mit Stromimpulsen (Ankündigung mittels Ton oder Vibration). Durch eine fehlende optische Markierung kann der Hund nicht lernen, dem Zaun auszuweichen, weil er keinen optischen Zusammenhang zwischen dem Draht und dem Stromschlag herstellen kann. Dies kann dazu führen, dass der Hund es überhaupt nicht mehr wagt, den Garten zu betreten. Zudem kann es zu Fehlverknüpfungen (z.B. mit anwesenden Personen) kommen => Verbot der Anwendung nach § 3 Nr. 11 Tierschutzgesetz und nach Tierschutz- Hundeverordnung.



## PDF page 5

- Bell-Stop-Geräte, egal ob sie elektrisch, chemisch, mittels Geräuschen oder Luftstoß arbeiten, sind abzulehnen, weil eine natürliche Kommunikationsform des Hundes, nämlich das Bellen, unterdrückt wird. Bellen bei alleingelassenen Hunden ist ein rudimentäres Wolfsverhalten, das ein Symptom von Angst, Stress und Frustration darstellt. Hier sind eine artgerechte Haltung und/oder eine Verhaltenstherapie angebracht. Das Bellen an der Reviergrenze (Grundstückgrenze) gehört zum normalen Territorialverhalten. Auch hier muss im Problemfall eine Verbesserung der Haltungsbedingungen und/oder eine Verhaltenstherapie eingeleitet werden => Verbot der Anwendung nach § 3 Nr. 11 Tierschutzgesetz (bei elektrischen Impulsen) und nach Tierschutz-Hundeverordnung.

- Andere Erziehungshalsbänder arbeiten mit unterschiedlichen Mechanismen, mittels eines Senders am Halsband wird beispielsweise ein kalter Wasserstrahl, Zitronenduft (Zitronella), Stickstoff oder ein kaltes Luft-Gasgemisch versprüht. Auch diese Erziehungsmaßnahmen sind kritisch zu beurteilen. Der Hund kann den Strafreiz in der Regel nicht mit seinem „Fehlverhalten“ in Verbindung bringen - insbesondere dann nicht, wenn das unerwünschte Verhalten und die Bestrafung nicht vollkommen zeitgleich erfolgen. Fehlverknüpfungen und die Entwicklung von Verhaltensstörungen können die Folge sein.

- Rütteldosen, Fisher-Discs etc.: Aus Tierschutzsicht ist der Einsatz von aversiven Reizen und positiver Strafe kritisch zu sehen, da beim Hund eine negative Emotion (Angst, Schreckreiz) entsteht. Das kann zu einer massiven Verunsicherung des Hundes führen. Zumal das richtige Timing beim Einsatz eines aversiven Reizes, einer positiven Strafe eine entscheidende Rolle spielt, damit der Hund sein Fehlverhalten mit dem Strafreiz in Verbindung bringen kann. Das ist in den seltensten Fällen gegeben. Außerdem besteht auch hier die Gefahr, dass es zu einer ungewollten negativen Verknüpfung mit bestimmten Personen, Orten oder Situationen kommen kann.

- Nylonmaulkörbe: Der Einsatz von Nylonmaulkörben ist grundsätzlich abzulehnen. Die Hunde können mit diesen weder hecheln, noch trinken oder ein Leckerli fressen. Der Einsatz sollte sich (wenn überhaupt), auf eine kurze Anwendung bei einer tiermedizinischen Untersuchung beschränken. Ansonsten müssen tierschutzgerechte Maulkörbe verwendet werden, die den Hunden ein hecheln ermöglichen. Damit der Hund den Maulkorb gerne trägt, muss er im Vorfeld positiv auftrainiert werden.

- Fellpflegeprodukte, die den arteigenen Geruch überdecken/neutralisieren (Shampoos, Sprays): Hunde kommunizieren über den Geruch, daher sollte der arteigene Geruch keinesfalls überdeckt oder neutralisiert werden. Sie sollten daher nur im Bedarfsfall, z.B. nach dem Wälzen in Kot oder Aas oder aber aufgrund einer medizinischen Indikation, mit einem milden Shampoo ohne Parfüm gebadet werden.

#### Spielzeug

- Bälle und anderes Wurfspielzeug: Es besteht die Gefahr des Verschluckens. Auf dem einzelnen Spielzeug sollte vermerkt sein, für welche Größenklasse es geeignet ist. Bei einigen Materialien (z.B. Vinyl = PVC) besteht die Gefahr auf Vergiftung und der Verletzung beim Zerbeißen und Verschlucken von einzelnen Teilen (Darmverschluss).



## PDF page 6

Am besten geeignet sind Vollgummiprodukte. Tennisbälle führen aufgrund ihrer Struktur zur Abnutzung der Zähne. Dies kann ebenfalls zur Eröffnung der Zahnpulpa führen, wodurch schmerzhafte Entzündungen entstehen und aufsteigen können. Zudem können sie beim Kaputt-Beißen schnell verschluckt werden und müssen in Vollnarkose und ggf. Eröffnung der Bauchhöhle aufwendig herausgeholt werden.

- Knochen: Leider immer noch gerne verwendet, stellen Knochen, egal, ob roh oder gekocht, egal ob vom Huhn, Schwein oder Rind eine Verletzungsgefahr für Zähne, Luftröhre und Darm dar. Dazu gehören auch die getrockneten Knochen vom Geflügel und Kaninchen, die es im Zoofachhandel zu kaufen gibt. Schweineohren oder andere getrocknete Schweineteile müssen bei der Herstellung so behandelt worden sein, dass die Übertragung von Infektionen ausgeschlossen werden kann (z.B. Erhitzen auf mindestens 80°C Kerntemperatur über zehn Minuten).

#### Unterbringung

Seit einiger Zeit finden sich Möbelstücke auf dem Markt, die gleichzeitig als Hundebox dienen sollen. Die Hundebox ist in einen Schrank oder Sitzbank integriert. Hundeboxen sollten lediglich für den eigentlichen Zweck der Nutzung durch einen Hund und nicht anderweitig oder in Kombination gedacht sein. Zudem ist auf eine entsprechende Größe zu achten z.B. sollte sich der Hund drehen, hinlegen und stehen können. Eine Hundebox ist kein Erziehungsmittel. Beispielsweise ist es tierschutzwidrig, einem Hund durch Einsperren in der Hundebox die Stubenreinheit beizubringen. Eine Hundebox kann auch in der Wohnung ein Ort der Entspannung und Sicherheit für den Hund darstellen, wenn diese groß genug ist, positiv verknüpft wurde und der Hund die Möglichkeit hat, diese nach Belieben zu verlassen. Ein längeres Einsperren z.B. über Nacht ist strikt abzulehnen!

#### Sonstiges

Jedes Zubehör, dass dem Menschen einen Vorteil verschafft und dem Tier Schmerzen, Leiden oder Schäden bereitet ist abzulehnen bzw. durch das Tierschutzgesetz verboten. Hierunter zählen z.B.: „Hängematten“ zum „Einhängen“ kleinerer Hunde, um Pflegemaßnahmen vorzunehmen, Krallenkappen, um den Boden zu schonen, Hundewindeln, die v.a. aus für den Menschen praktischen Gründen in der Läufigkeit eingesetzt werden. Auch Vermenschlichung ist meist nicht tierschutzgerecht wie z.B. jegliche Verkleidung zur Belustigung, feierlichen Anlässen etc., die nicht darauf abzielt das Tier vor der Witterung zu schützen.

### Kleine Heimtiere

#### Zubehör

- Allgemein sind serienmäßig hergestellte Haltungssysteme für kleine Heimtiere in der Regel zu klein, falsch konstruiert und falsch ausgestattet.

- Reine Plastik- oder Glaskäfige bieten eine schlechte Belüftung. Allseitig geschlossene Behältnisse schränken die Luftzirkulation stark ein und behindern die Wahrnehmung der Umgebung. Das Tier kann sich nicht dem Geruch und der Schadgasansammlung am Boden entziehen. Es kann zudem zu starker Staubentwicklung und Wärmestau kommen.



## PDF page 7

Der Tierhalter empfindet weniger Geruchbelästigung, dadurch wird die Dringlichkeit der Reinigung verschleiert. Die Gasanreicherungen können dem Tier Schäden wie z.B. Schleimhautreizungen, Atemwegserkrankungen oder Entzündungen an der Haut zufügen.

- Plastik ist als Material für Gehege und Strukturierungselemente in der Regel ungeeignet, da eine Verletzungs- und Verschluckungsgefahr durch Annagen besteht.

- Schlafhäuschen mit zu kleinen Ein- und Ausgängen oder Fenstern bergen die Gefahr, dass Tiere hängen bleiben. Deswegen sollte der Durchmesser der Öffnungen immer passend zur gehaltenen Tierart gewählt werden. Fenster braucht es nicht. Zu vermeiden ist darüber hinaus, dass Häuschen nur einen Ein- / Ausgang haben. Besser sind mindestens zwei, damit sich die Tiere aus dem Weg gehen können und bei Rangstreitigkeiten keine Sackgassen vorhanden sind.

- Hamsterwatte / Nagerwatte: Durch die faserige Struktur besteht die Gefahr der Verstopfung der Backentaschen von Hamstern sowie der Abschnürung von Gliedmaßen. Als Polstermaterial eignen sich besser Heu, Papierschnipsel oder Zellstoff.

- Einstreu, die mit Duft- oder Farbstoffen behandelt wurde, stört das feine Geruchsempfinden der Tiere. Zudem werden über Urin, Kot und Duftdrüsen wichtige Markierungen im Gehege gesetzt und Gruppengerüche verteilt. Dieses wichtige Verhalten wird durch parfümierte Einstreu gestört, weswegen auf dessen Verwendung verzichtet werden sollte.

- Futterraufen ohne Abdeckung: Tiere können hineinspringen und beim Verlassen hängen bleiben.

#### Spielzeug

- Kleidung, Geschirre, Leinen für Kaninchen, Meerschweinchen, Hamster o. Ä.: Die üblicherweise als Haustiere gehaltenen kleinen Heimtiere sind Fluchttiere. Längeres anfassen und Zwangsmaßnahmen wie Anziehen bedeutet Stress für die Tiere.

- Laufräder mit Gittersprossen, die an beiden Seiten offen sind, bergen eine Verletzungsgefahr durch Einklemmen von Gliedmaßen oder Brechen der Wirbelsäule. Sie haben außerdem oft scharfe Kanten oder sind aus Plastik, welcher von den Tieren angeknabbert und verschluckt wird. Tierschutzgerecht sind Laufräder, deren Durchmesser so groß sind, dass die jeweilige Tierart ohne gekrümmte Wirbelsäule darin laufen kann. Die Lauffläche und eine Seitenfläche sollten geschlossen sein und es muss stabil angebracht sein.

- Röhrensysteme: In senkrechten und stark geneigten Röhren sowie bei Röhren mit Öffnungen, die nach unten zeigen besteht Verletzungsgefahr. Lange Röhrensysteme können nicht leicht gereinigt werden und sind schlecht belüftbar. Es bildet sich Kondenswasser, in welchem sich Krankheitserreger vermehren können. Das transparente Material bietet keine Rückzugsmöglichkeit für die Tiere. Diese Systeme können das natürliche Grabebedürfnis der Tiere nicht befriedigen. Kunststoffröhren sind nur dann akzeptabel, wenn sie höchstens die doppelte Körperlänge des Tieres haben, eine ausreichende Belüftung gewährleisten und mit einer Gebrauchsanleitung versehen sind, die deutlich macht, dass



## PDF page 8

derartige Röhren nicht missbräuchlich verwendet werden dürfen. Röhren aus Naturmaterialien (z. B. Sisal, Ton) sind Kunststoffröhren vorzuziehen.

- Hamsterkugel: Es handelt sich um ganz oder teilweise transparente Plastikkugeln von verschiedenen Durchmessern (10 bis 15 cm), die mit kleinen Lüftungsschlitzen versehen sind. Manchmal werden die Kugeln mit Ständern angeboten und dienen dann quasi als komplett geschlossene Hamsterlaufräder. Durch den Aufenthalt in einer solchen Kugel können dem Hamster erhebliche Leiden und Schäden zugefügt werden. Der Hamster kann weder sich selbst aus der Kugel befreien, noch ist er in der Lage, Geschwindigkeit und Richtung der Fortbewegung der Kugel durch seine eigene Aktivität zu steuern. Vielmehr ist davon auszugehen, dass das Tier durch fehlende Orientierungsmöglichkeit sowie durch fehlende Rückzugsmöglichkeit besonders in einer transparenten Kugel in eine Stresssituation gerät. Das Tier kann seinem natürlichen Bedürfnis in Deckung zu gehen nicht nachkommen. Darüber hinaus besteht erhebliche Verletzungsgefahr: Die Kugel kann abrupt irgendwo anstoßen, kann Herunterfallen von Tischen, Treppen etc. und die kleinen Lüftungsschlitze gewährleisten keine ausreichende Sauerstoffversorgung.

- "Hamsterautos", bei denen die Räder ins Rollen kommen, sobald der Hamster im Laufrad läuft, können zu Knochenbrüchen führen. Sowohl bei Hamsterautos als auch bei Hamsterkugeln wird zudem oft die natürliche Nachtaktivität und Tagesruhe der Tiere missachtet.

#### Sonstiges

- Alleinfutter für Kaninchen oder Meerschweinchen: Getreidehaltiges Alleinfutter entspricht nicht den natürlichen Ernährungsbedürfnissen der Kaninchen oder Meerschweinchen. Rohfaserhaltiges Futter wie Heu und Grünfutter muss die Ernährungsgrundlage sein. Körnerfutter wird i.d.R. nicht benötigt!

- Nagersteine: Bei einer ausgewogenen Ernährung sind weder Salz- noch sonstige Nagersteine notwendig, sie sind sogar schädlich, wenn zu große Mengen aufgenommen werden.

### Vögel

#### Zubehör

- Käfige, die nicht den Mindestanforderungen an eine artgerechte Haltung entsprechen, sind abzulehnen. Die meisten Käfige aus dem Zoofachhandel entsprechen nicht den Mindestanforderungen und sind in der Regel deutlich zu klein. Generell sind große, gut strukturierte Volieren zu empfehlen, angepasst an die jeweilige Tierart, sowie Gruppegröße, die den Tieren Verstecke, Rückzugsmöglichkeiten und Sicherheit bieten.

- Rundkäfige oder Turmvolieren sind strikt abzulehnen, da sich die Vögel darin nicht orientieren können. Die Vögel können nur steil von unten nach oben und umgekehrt hüpfen, was nicht ihrem natürlichen Bewegungsbedürfnis entspricht, sich vorwiegend horizontal durch Fliegen oder zumindest von Ast zu Ast hüpfend fortzubewegen. Durch diese tierschutzwidrige Einschränkung der physiologischen Bewegungsabläufe werden den Tieren erhebliche, stressbedingte Leiden und Schäden durch die Fehlbelastung der Gelenke zugefügt.



## PDF page 9

Die Tiere können nicht fliegen, was zu Gewichtszunahme und einer Mangelbelüftung des Luftsacksystems und der Ständer führen kann. Zudem können Sitzstangen in einem Rundkäfig nicht sinnvoll angebracht werden. Die unteren Sitzstangen und gegebenenfalls auch das Futter werden verkotet (Hygieneproblem). Auch kann ein solcher Käfig nicht artgerecht strukturiert werden, deswegen treten Orientierungsprobleme und damit verbundener zusätzlicher Stress auf.

- Käfige mit weißen Gittern: Flimmereffekt der Gitterstäbe, die Vögel werden dadurch in ihrer Wahrnehmung und ihrem Orientierungsvermögen gestört.

- Kunststoffüberzogene und lackierte Käfiggitter sind für Vögel grundsätzlich ungeeignet, da diese die Gitterüberzüge abnagen können. Hier besteht Vergiftungsgefahr.

- Kunststoff-Sitzstangen sind generell abzulehnen, da sie zu glatt und statisch sind. Sie bieten den Tieren keinen sicheren Stand und führen zu Fehlbelastungen der Ballen und schlussendlich Sohlenballenentzündungen.

- Vertikale Käfigstangen sind ungeeignet zum Klettern.

- Mit Sandpapier umwickelte Sitzstangen können die Ballen und den Schnabel beim Wetzen verletzen und zu schlecht heilenden Wunden führen.

- Sitzstangen mit gleichem Durchmesser führen oft zu Ballengeschwüren durch die gleichförmige Belastung der Ballen, deswegen ungiftige, ungespritzte Naturäste als Sitzstangen verwenden, die auf einer Seite im Käfig angebracht werden, so dass die Tiere darauf schwingen können wie in der freien Natur.

- Sandpapier als Einstreuersatz: Sandpapier am Käfigboden kann zu kleinen Verletzungen und Rissen auf der Haut der Vogelfüße führen. Die dadurch entstehenden Mikroläsionen können als Eintrittspforte für schädliche Erreger dienen. Oft entspricht die Saugfähigkeit nicht der des üblichen Vogelsandes. Keime vermehren sich in einem feuchten Milieu besonders stark.

#### Spielzeug

- Spiegel und Plastikvögel: Diese "Spielgefährten" führen zu Verhaltensstörungen beim Vogel und es kann zudem durch fehlgesteuertes Fütterungsverhalten zu Kropfentzündungen kommen, da das vermeintliche Partnertier das hochgewürgte Futter nicht annehmen kann. Auf Dauer führt dies zu Frustration und Aggression

- Spielzeug mit Schlaufen, Karabinern, Ringen oder Kleinteilen, in denen sich der Vogel verfangen und verletzten oder sogar strangulieren kann, ist ungeeignet.

- Seile: Bei locker aufgedrehten oder geflochtenen Seilen, z.B. aus Hanf, besteht bei Ablösung einzelner Fasern die Gefahr der Strangulation von Kopf und Gliedmaßen(teilen) oder auch die Gefahr des Verschluckens.

- Gefärbtes/geklebtes Spielzeug => Vergiftungsgefahr

- Glänzende Gegenstände => Gefahr des Verschluckens

- Rechenmaschinen für Vögel: Die Tiere können einzelne Perlen aufnehmen, was zu Kropfschäden und anderen Gesundheitsproblemen führen kann.



## PDF page 10

- Papageienfreisitze mit Ankettung bieten den Tieren keine ausreichende Möglichkeit zur ungehinderten Bewegung. Es besteht Verletzungsgefahr durch Hängenbleiben und bei Angst- und Panikreaktionen beim Losfliegen.

- Brustgeschirre für Papageien sind abzulehnen, da sie für die Tiere eine große Verletzungsgefahr darstellen

#### Sonstiges

- Flackernde Beleuchtung ist tierschutzwidrig. Vögel sehen das Licht normaler Leuchtstoffröhren und LEDs als Flackern, was zu erheblichem Stress führt und gesundheitliche sowie verhaltensbedingte Folgen haben kann. Um eine flackerfreie Beleuchtung zu gewährleisten, sollten idealerweise HF-Leuchtstoffröhren eingesetzt werden. Bei Verwendung von Emissionsröhren, nicht-flackerfreien LEDs oder Energiesparlampen müssen elektrische Vorschaltgeräte (EVGs) eingesetzt werden, um eine Flackerfreiheit zu gewährleisten. Glühlampen sollten für die Beleuchtung einer Vogelhaltung nicht mehr verwendet werden.

### Reptilien

#### Zubehör

- Miniterrarien für Wasserschildkröten mit Schildkröteninseln: Sowohl der Land- als auch der Wasserteil sind in solchen Miniterrarien viel zu klein dimensioniert. Es fehlen fast alle Ausrüstungsgegenstände (Wasserfilter, Heizung, Beleuchtung etc.). Zudem können Plastikinseln beim Anknabbern verschluckt werden und zu tödlichen Verstopfungen und Vergiftungen führen.

- Netzhängematten für Leguane: Tiere können sich damit strangulieren.

- Bekleidung für Reptilien (Lederjacken für Leguane): Verletzungsgefahr durch Abwehrbewegungen beim Anziehen und Hängenbleiben an Zweigen, zusätzlich wird die Bewegungsfreiheit eingeschränkt, der Rückenkamm kann abknicken, es kommt zu unzureichender UV- Versorgung und dadurch zu Hautproblemen.

- Brustgeschirre für Leguane: Leguane sind nicht zur Leinenführigkeit zu bringen und es widerspricht ihrem arteigenen Verhalten. Sie als Begleittier außerhalb des Hauses wie einen Hund mitzunehmen, verstößt in unseren Breitengraden schon aus klimatischen Gründen gegen tierschutzrechtliche und -ethische Grundsätze. In der Wohnung bergen solche Geschirre die Gefahr, dass sich die Tiere damit an Einrichtungsgegenständen verfangen.

- Panzerpflegepräparate für Schildkröten: Schildkrötenpanzer benötigen keine Pflege. Durch das Auftragen von Ölen kommt es zur Verstopfung der Poren, der Panzer wird spröde oder speckig. Außerdem wird der normale Häutungsvorgang behindert, was Infektionen begünstigen kann. Durch Bepflanzen des Geheges z.B. mit Lavendel wird der Panzer durch die im Lavendel enthaltenen ätherischen Öle auf natürliche Weise gepflegt, wenn das Tier den Strauch streift.



## PDF page 11

### Fische

#### Zubehör

- Goldfischkugeln: Darin gehaltene Fische leiden wegen fehlender Rückzugsmöglichkeiten und mangelnder Orientierung an Stresszuständen. Darüber hinaus sind durch fehlenden Filter und die geringe Größe der Kugel keine stabilen Wasserwerte einstellbar, was zu erheblichen Beeinträchtigungen des Gesundheitszustandes führt, unter Umständen bis zum Tod. Durch die kleine Wasseroberfläche ist nur ein unzureichender Austausch mit Luftsauerstoff möglich. Die Fische erhalten einen stark verzerrten optischen Eindruck der Umgebung und aufgrund der Formgebung gibt es eine oft fischschädliche Aufheizung des Wassers während der warmen Jahreszeit.

- Miniaturaquarien, Säulenaquarien, „Lebende Gemälde“: Bieten Fischen keine ausreichende Bewegungsmöglichkeit. Außerdem können keine stabilen Wasserwerte erreicht werden. Für die Haltung von Zierfischen sind Säulenaquarien ungeeignet, sofern der Durchmesser wesentlich geringer als die Höhe ist. Bei solchen Aquarien ist die Oberfläche, an der der Gasaustausch stattfindet in Relation zum Wasservolumen zu gering. Die runde Form macht bei kleinem Durchmesser einen Rückzug der Fische bei Stress unmöglich. Im besonderen Maße tierschutzwidrig sind Säulenaquarien mit sehr kleinem Durchmesser, wenn darin Fische gehalten werden, deren Körperlänge diesem Durchmesser nahezu entspricht. Tierschutzwidrig sind auch Säulenaquarien, in denen sich Luftblasen zu Dekorationszwecken bilden. Die Fische werden ständig zwangsweise auf- und ab bewegt, was eindeutig als Verstoß gegen § 2 des Tierschutzgesetzes zu werten ist.

- Aquarien-Einsteigersets mit einer Länge von weniger als 60 Zentimetern (54 Liter): Gerade Einsteigern bereitet die Einstellung eines biologischen Gleichgewichts im Aquarium oft große Schwierigkeiten. Je größer das Wasservolumen ist, desto leichter wird ein solches Gleichgewicht erreicht. Aquarien mit einem Fassungsvermögen von 54 Litern stellen diesbezüglich eine absolute Untergrenze dar.

- Ungeeigneter Kies: Hochofenschlacken geben im sauren Milieu giftige Chemikalien ab; scharfkantiger Kies (z.B. Basaltkies) stellt Gefahr für die Barteln gründelnder Arten dar; "Glitzersteine" erzeugen starke Lichtreflexionen, gefärbter Kies für den Aquariengrund kann je nach Färbemittel Giftstoffe ins Wasser abgeben.

- Ungeeignete Dekorationsgegenstände: Modellfiguren, Wuzeln, Steine oder Holz, die nicht wasserstabil und –neutral sind, können Schadstoffe (z.B. Schwermetalle, Mikroplastik) oder Mineralstoffe abgeben und die Wasserqualität und Gesundheit der Zierfische gefährden.



## PDF page 12

### Forderung des Deutschen Tierschutzbundes

Der Deutsche Tierschutzbund setzt sich seit Jahren dafür ein, dass tierschutzwidriges Zubehör wie Stachelhalsbänder, Vogelstangen mit Sandpapierüberzug und ähnliches vom Markt genommen wird und durch tierschutzgerechtes Zubehör ersetzt wird. Letzteres sollte für den Verbraucher gekennzeichnet werden. Eine Heimtierschutzverordnung könnte tierschutzwidriges Zubehör listen und somit verhindern, dass es weiterhin auf dem Markt verfügbar ist. Das zeichnet tierschutzgerechtes Zubehör aus:

- Es ist so gekennzeichnet, dass erkennbar ist, für welche Tierart, und, soweit erforderlich, für welche Anzahl an Tieren das jeweilige Produkt geeignet ist.

- Von dem Material darf kein schädigender Einfluss auf die Gesundheit der Tiere ausgehen. Natürlichen Materialien sollte, soweit mit hygienischen Aspekten vereinbar, der Vorzug gegeben werden.

- Das Zubehör muss so beschaffen sein, dass eine Verletzungsgefahr für die Tiere ausgeschlossen ist. Dabei sind artspezifische Verhaltensweisen, z.B. das Benagen von Gegenständen, entsprechend zu berücksichtigen.

- Ziel des Produktes ist nicht optische Vorlieben des Menschen zu befriedigen, sondern das gehaltene Tier in der Ausübung arteigener Verhaltensweisen zu unterstützen

### Quellen

TVT Merkblatt Nr. 62: Tierschutzwidriges Zubehör in der Heimtierhaltung TVT Merkblatt Nr. 194: Tierschutzwidriges Zubehör Hund TVT Merkblatt Nr. 195 Tierschutzwidriges Zubehör Katze TVT-Stellungnahme zu dem Fluggeschirr „AVIATOR™“ (2018) Döring D, Schneider B, Erhard M, Schönreiter S (2022): Verwendung von abschließbaren Hundeboxen im Alltag. Deutsches Tierärzteblatt 70 (3): 306-313. Döring D, Schneider B, Erhard M, Schönreiter S (2023): Hunde im Käfig –sinnvoller Trend oder tierschutzwidrig? Team konkret 1/2023.
