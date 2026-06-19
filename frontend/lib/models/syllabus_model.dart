enum SyllabusLevel { subject, chapter, topic, subtopic }

class SyllabusNode {
  final String title;
  final SyllabusLevel level;
  final List<SyllabusNode> children;

  const SyllabusNode({
    required this.title,
    required this.level,
    this.children = const [],
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // BPSC PRELIMS — General Studies Paper I (Complete Syllabus)
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<SyllabusNode> bpscPrelimsSyllabus = [
    // ─── 1. History ──────────────────────────────────────────────────────────
    SyllabusNode(
      title: 'History',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Ancient History',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Indus Valley Civilization',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Town Planning & Architecture', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Society and Religion', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Economic Life & Trade', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Decline of Harappan Civilization', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Vedic Period',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Early Vedic Age (Rig Vedic Period)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Later Vedic Age', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Vedic Literature & Philosophy', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Buddhism & Jainism',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Life of Buddha & Teachings', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Buddhist Councils & Sangha', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Mahavira & Jain Teachings', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Spread of Buddhism from Bihar', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Maurya Empire',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Chandragupta Maurya & Kautilya', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Ashoka & Dhamma Policy', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Mauryan Administration', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Art & Architecture (Pillars, Stupas)', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Post-Mauryan Period',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Shunga, Kanva & Satavahana Dynasties', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Indo-Greek, Shaka & Kushana Dynasties', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Gupta Empire',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Samudragupta & Chandragupta II', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Golden Age of Indian Culture', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Science, Literature & Art', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Nalanda & Vikramashila Universities', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
        SyllabusNode(
          title: 'Medieval History',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Delhi Sultanate',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Slave Dynasty', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Khilji Dynasty & Market Reforms', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Tughlaq Dynasty', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Sayyid & Lodi Dynasties', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Administration & Revenue System', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Mughal Empire',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Babur & Foundation of Mughal Rule', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Akbar — Administration & Policies', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Jahangir, Shah Jahan & Aurangzeb', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Mughal Art, Architecture & Culture', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Decline of the Mughal Empire', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Bhakti & Sufi Movements',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Bhakti Saints (Kabir, Ramananda, Tulsidas)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Sufi Orders (Chishti, Suhrawardi)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Impact on Society & Culture', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Maratha Empire',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Shivaji & Maratha Administration', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Peshwa Period & Third Battle of Panipat', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
        SyllabusNode(
          title: 'Modern History',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Advent of Europeans',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Portuguese, Dutch, French & British', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Battle of Plassey & Buxar', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Dual Government in Bengal/Bihar', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'British Administration & Policies',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Revenue Systems (Permanent Settlement, Ryotwari, Mahalwari)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Social & Educational Reforms', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Economic Drain of Wealth', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Revolt of 1857',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Causes of the Revolt', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Role of Kunwar Singh (Bihar)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Bihar in the 1857 Revolt', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Consequences & Government of India Act 1858', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Indian National Movement',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Formation of INC & Moderates', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Extremist Movement & Partition of Bengal', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Gandhian Era & Mass Movements', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Champaran Satyagraha (1917)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Non-Cooperation Movement', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Civil Disobedience Movement', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Quit India Movement (1942)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Role of Bihar in Freedom Struggle', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Post-Independence India',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Integration of States', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Five Year Plans', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Formation of Bihar & Jharkhand Separation', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
      ],
    ),

    // ─── 2. Geography ────────────────────────────────────────────────────────
    SyllabusNode(
      title: 'Geography',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Physical Geography',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'The Earth',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Interior of the Earth', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Earthquakes & Volcanoes', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Plate Tectonics', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Climatology',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Atmosphere & Weather', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Indian Monsoon System', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Climate Change & Global Warming', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
        SyllabusNode(
          title: 'Indian Geography',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Physical Features of India',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'The Himalayas', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Northern Plains (Indo-Gangetic)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Peninsular Plateau', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Coastal Plains & Islands', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Drainage System',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Himalayan Rivers', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Peninsular Rivers', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Natural Resources',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Minerals & Mining', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Agriculture & Irrigation', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Energy Resources', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Population & Urbanization',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Census & Demographics', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Urbanization Trends', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Migration Patterns', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
        SyllabusNode(
          title: 'Geography of Bihar',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Physical Features of Bihar',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Bihar Plain & Chotanagpur Plateau', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Climate of Bihar', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Soils of Bihar', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Drainage System of Bihar',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Ganga River System', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Kosi, Gandak, Son & Other Rivers', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Flood Management', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Agriculture in Bihar',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Major Crops (Rice, Wheat, Maize, Litchi)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Irrigation Systems', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Green Revolution in Bihar', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Industries & Minerals',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Major Industries in Bihar', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Mineral Resources', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
      ],
    ),

    // ─── 3. Indian Polity ────────────────────────────────────────────────────
    SyllabusNode(
      title: 'Indian Polity',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Indian Constitution',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Making of the Constitution',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Constituent Assembly & Key Members', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Preamble', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Sources of the Constitution', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Salient Features', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Fundamental Rights (Part III)',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Right to Equality (Art. 14-18)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Right to Freedom (Art. 19-22)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Right against Exploitation (Art. 23-24)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Right to Constitutional Remedies (Art. 32)', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Directive Principles & Fundamental Duties',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'DPSP (Part IV) — Classification', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Fundamental Duties (Art. 51A)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'DPSP vs Fundamental Rights', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Union Government',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'President & Vice-President', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Prime Minister & Council of Ministers', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Parliament (Lok Sabha & Rajya Sabha)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Supreme Court', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'State Government',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Governor & Chief Minister', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'State Legislature', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'High Court', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Bihar State Government Structure', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Local Self Government',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Panchayati Raj System (73rd Amendment)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Municipalities (74th Amendment)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Bihar Panchayati Raj Act', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
        SyllabusNode(
          title: 'Governance & Public Policy',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Constitutional & Statutory Bodies',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Election Commission', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'CAG, UPSC, BPSC', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Finance Commission', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'NHRC, SHRC, NCW', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Important Constitutional Amendments',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: '42nd, 44th, 73rd, 74th, 86th, 101st Amendments', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
      ],
    ),

    // ─── 4. Economy ──────────────────────────────────────────────────────────
    SyllabusNode(
      title: 'Economy',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Indian Economy',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Economic Planning',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Five Year Plans & NITI Aayog', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'LPG Reforms (1991)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'GDP, GNP & National Income', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Agriculture',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Green Revolution', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Land Reforms', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Food Security & PDS', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Agricultural Marketing (MSP, APMC)', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Banking & Finance',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'RBI & Monetary Policy', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Banking Sector Reforms', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Capital Markets (SEBI)', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Financial Inclusion & Jan Dhan', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Fiscal Policy & Budget',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Union Budget & Key Terms', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'GST & Taxation', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Fiscal Deficit & Revenue Deficit', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Poverty & Employment',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Poverty Alleviation Programs', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'MGNREGA', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Unemployment Types & Measures', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'International Trade',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'WTO, IMF, World Bank', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Balance of Payments', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'FDI & FPI', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
        SyllabusNode(
          title: 'Bihar Economy',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Bihar\'s Economic Profile',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'GSDP & Growth Rate', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Bihar Budget', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Seven Nischay (Saat Nischay) Scheme', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Industrial Policy of Bihar', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
      ],
    ),

    // ─── 5. General Science ──────────────────────────────────────────────────
    SyllabusNode(
      title: 'General Science',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Physics',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Mechanics',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Newton\'s Laws of Motion', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Work, Energy & Power', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Gravitation', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Heat & Thermodynamics',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Laws of Thermodynamics', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Heat Transfer (Conduction, Convection, Radiation)', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Optics & Sound',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Reflection & Refraction', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Lenses & Mirrors', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Sound Waves & Doppler Effect', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Electricity & Magnetism',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Current Electricity & Ohm\'s Law', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Electromagnetic Induction', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Transformers & Generators', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Nuclear Physics',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Radioactivity & Nuclear Fission/Fusion', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Nuclear Energy Programs in India', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
        SyllabusNode(
          title: 'Chemistry',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Basic Chemistry',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Atomic Structure & Periodic Table', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Chemical Bonding', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Acids, Bases & Salts', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Everyday Chemistry',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Metals & Alloys', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Polymers & Plastics', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Soaps, Detergents & Fertilizers', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
        SyllabusNode(
          title: 'Biology',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Human Body',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Digestive System', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Circulatory System', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Nervous System', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Endocrine System & Hormones', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Diseases & Nutrition',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Communicable & Non-Communicable Diseases', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Vitamins & Deficiency Diseases', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Vaccines & Immunization', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Genetics & Evolution',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'DNA, RNA & Genetics', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Evolution & Darwin\'s Theory', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Biotechnology & GMOs', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Plant Biology',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Photosynthesis & Respiration', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Plant Hormones', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Classification of Plants', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
      ],
    ),

    // ─── 6. Environment & Ecology ────────────────────────────────────────────
    SyllabusNode(
      title: 'Environment & Ecology',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Ecology Basics',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Ecosystems',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Types of Ecosystems', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Food Chains & Food Webs', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Biogeochemical Cycles', level: SyllabusLevel.subtopic),
              ],
            ),
            SyllabusNode(
              title: 'Biodiversity',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Biodiversity Hotspots in India', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Endangered & Endemic Species', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Wildlife Protection Act', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'National Parks & Sanctuaries in Bihar', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
        SyllabusNode(
          title: 'Environmental Issues',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(
              title: 'Pollution & Conservation',
              level: SyllabusLevel.topic,
              children: [
                SyllabusNode(title: 'Air, Water & Soil Pollution', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Climate Change & Paris Agreement', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Sustainable Development Goals', level: SyllabusLevel.subtopic),
                SyllabusNode(title: 'Environmental Impact Assessment', level: SyllabusLevel.subtopic),
              ],
            ),
          ],
        ),
      ],
    ),

    // ─── 7. Current Affairs ──────────────────────────────────────────────────
    SyllabusNode(
      title: 'Current Affairs',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'National Current Affairs',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Government Schemes & Policies', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Awards & Honours', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Important Appointments', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Sports Events & Achievements', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'International Current Affairs',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'International Organizations', level: SyllabusLevel.topic),
            SyllabusNode(title: 'India\'s Foreign Relations', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Summits & Conferences', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'Bihar Current Affairs',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Bihar Government Schemes', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Bihar Awards & Events', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Development Projects', level: SyllabusLevel.topic),
          ],
        ),
      ],
    ),

    // ─── 8. Bihar Special ────────────────────────────────────────────────────
    SyllabusNode(
      title: 'Bihar Special',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Bihar History',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Ancient Bihar (Magadha, Nalanda, Vikramashila)', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Medieval Bihar', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Bihar in Freedom Struggle', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Post-Independence Bihar', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'Bihar Culture & Society',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Festivals (Chhath, Sonepur Mela)', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Folk Art (Madhubani, Tikuli)', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Languages & Literature', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Famous Personalities of Bihar', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'Bihar Administration',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Bihar Legislative Assembly & Council', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Bihar Public Service Commission (BPSC)', level: SyllabusLevel.topic),
            SyllabusNode(title: 'District Administration', level: SyllabusLevel.topic),
          ],
        ),
      ],
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // BPSC MAINS — General Studies Papers I to IV
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<SyllabusNode> bpscMainsSyllabus = [
    // ─── GS Paper I: Indian Heritage & Culture, History, Geography ────────
    SyllabusNode(
      title: 'GS Paper I — Indian Heritage & Culture, History, Geography',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Indian Culture',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Art Forms, Literature & Architecture', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Ancient to Modern History', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Freedom Struggle & National Movement', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'World & Indian Geography',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Physical, Social & Economic Geography', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Disasters & Disaster Management', level: SyllabusLevel.topic),
          ],
        ),
      ],
    ),

    // ─── GS Paper II — Governance, Polity, Social Justice, International ──
    SyllabusNode(
      title: 'GS Paper II — Governance, Polity, Constitution, Social Justice',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Governance & Constitution',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Indian Constitution — Features, Amendments, Key Provisions', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Separation of Powers', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Federalism & Centre-State Relations', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Dispute Redressal Mechanisms', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'Social Justice',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Welfare Schemes for Vulnerable Sections', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Issues Related to Education & Health', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Issues Related to Women & Children', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'International Relations',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'India\'s Foreign Policy', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Bilateral & Multilateral Relations', level: SyllabusLevel.topic),
            SyllabusNode(title: 'International Organizations', level: SyllabusLevel.topic),
          ],
        ),
      ],
    ),

    // ─── GS Paper III — Technology, Economy, Environment, Security ────────
    SyllabusNode(
      title: 'GS Paper III — Technology, Economic Development, Environment, Security',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Economy & Development',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Indian Economy — Growth, Development & Employment', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Government Budgeting & Fiscal Policy', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Agriculture & Food Processing', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Infrastructure — Energy, Ports, Roads', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'Science & Technology',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Developments in S&T', level: SyllabusLevel.topic),
            SyllabusNode(title: 'IT, Space & Computer Technology', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Biotechnology & IPR Issues', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'Environment & Disaster Management',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Conservation & Pollution', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Disaster Management (Bihar-specific)', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'Internal Security',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Internal Security Challenges', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Linkages of Organized Crime & Terrorism', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Role of Media & Social Networking', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Cyber Security', level: SyllabusLevel.topic),
          ],
        ),
      ],
    ),

    // ─── GS Paper IV — Ethics, Integrity, Aptitude ───────────────────────
    SyllabusNode(
      title: 'GS Paper IV — Ethics, Integrity & Aptitude',
      level: SyllabusLevel.subject,
      children: [
        SyllabusNode(
          title: 'Ethics & Moral Thinkers',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Ethics & Human Interface', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Attitude — Content, Structure, Function', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Contributions of Moral Thinkers (Indian & Western)', level: SyllabusLevel.topic),
          ],
        ),
        SyllabusNode(
          title: 'Public Administration Ethics',
          level: SyllabusLevel.chapter,
          children: [
            SyllabusNode(title: 'Emotional Intelligence & Its Application', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Public Service Values & Ethics in Governance', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Probity in Governance — Information Sharing & Transparency', level: SyllabusLevel.topic),
            SyllabusNode(title: 'Case Studies on Ethical Dilemmas', level: SyllabusLevel.topic),
          ],
        ),
      ],
    ),
  ];
}
