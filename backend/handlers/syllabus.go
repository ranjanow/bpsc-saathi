package handlers

import (
	"encoding/json"
	"log"
	"net/http"
)

// ─────────────────────────────────────────────────────────────────────────────
// Syllabus API — returns the complete BPSC syllabus as structured JSON.
//
// GET /api/v1/syllabus
// ─────────────────────────────────────────────────────────────────────────────

// SyllabusNode represents a single node in the syllabus tree.
type SyllabusNode struct {
	Title    string         `json:"title"`
	Level    string         `json:"level"` // "subject", "chapter", "topic", "subtopic"
	Children []SyllabusNode `json:"children,omitempty"`
}

// SyllabusResponse wraps both Prelims and Mains syllabi.
type SyllabusResponse struct {
	Prelims []SyllabusNode `json:"prelims"`
	Mains   []SyllabusNode `json:"mains"`
}

// HandleGetSyllabus returns the complete BPSC syllabus (Prelims + Mains).
func HandleGetSyllabus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed","code":405}`, http.StatusMethodNotAllowed)
		return
	}

	log.Println("[Syllabus] Serving complete BPSC syllabus")

	response := SyllabusResponse{
		Prelims: bpscPrelimsSyllabus,
		Mains:   bpscMainsSyllabus,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("[Syllabus] ❌ Failed to encode response: %v", err)
	}
}

// ═══════════════════════════════════════════════════════════════════════════
// Complete BPSC Prelims Syllabus — GS Paper I
// ═══════════════════════════════════════════════════════════════════════════

var bpscPrelimsSyllabus = []SyllabusNode{
	// ─── 1. History ───────────────────────────────────────────
	{
		Title: "History", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Ancient History", Level: "chapter", Children: []SyllabusNode{
				{Title: "Indus Valley Civilization", Level: "topic", Children: []SyllabusNode{
					{Title: "Town Planning & Architecture", Level: "subtopic"},
					{Title: "Society and Religion", Level: "subtopic"},
					{Title: "Economic Life & Trade", Level: "subtopic"},
					{Title: "Decline of Harappan Civilization", Level: "subtopic"},
				}},
				{Title: "Vedic Period", Level: "topic", Children: []SyllabusNode{
					{Title: "Early Vedic Age (Rig Vedic Period)", Level: "subtopic"},
					{Title: "Later Vedic Age", Level: "subtopic"},
					{Title: "Vedic Literature & Philosophy", Level: "subtopic"},
				}},
				{Title: "Buddhism & Jainism", Level: "topic", Children: []SyllabusNode{
					{Title: "Life of Buddha & Teachings", Level: "subtopic"},
					{Title: "Buddhist Councils & Sangha", Level: "subtopic"},
					{Title: "Mahavira & Jain Teachings", Level: "subtopic"},
					{Title: "Spread of Buddhism from Bihar", Level: "subtopic"},
				}},
				{Title: "Maurya Empire", Level: "topic", Children: []SyllabusNode{
					{Title: "Chandragupta Maurya & Kautilya", Level: "subtopic"},
					{Title: "Ashoka & Dhamma Policy", Level: "subtopic"},
					{Title: "Mauryan Administration", Level: "subtopic"},
					{Title: "Art & Architecture (Pillars, Stupas)", Level: "subtopic"},
				}},
				{Title: "Post-Mauryan Period", Level: "topic", Children: []SyllabusNode{
					{Title: "Shunga, Kanva & Satavahana Dynasties", Level: "subtopic"},
					{Title: "Indo-Greek, Shaka & Kushana Dynasties", Level: "subtopic"},
				}},
				{Title: "Gupta Empire", Level: "topic", Children: []SyllabusNode{
					{Title: "Samudragupta & Chandragupta II", Level: "subtopic"},
					{Title: "Golden Age of Indian Culture", Level: "subtopic"},
					{Title: "Science, Literature & Art", Level: "subtopic"},
					{Title: "Nalanda & Vikramashila Universities", Level: "subtopic"},
				}},
			}},
			{Title: "Medieval History", Level: "chapter", Children: []SyllabusNode{
				{Title: "Delhi Sultanate", Level: "topic", Children: []SyllabusNode{
					{Title: "Slave Dynasty", Level: "subtopic"},
					{Title: "Khilji Dynasty & Market Reforms", Level: "subtopic"},
					{Title: "Tughlaq Dynasty", Level: "subtopic"},
					{Title: "Sayyid & Lodi Dynasties", Level: "subtopic"},
					{Title: "Administration & Revenue System", Level: "subtopic"},
				}},
				{Title: "Mughal Empire", Level: "topic", Children: []SyllabusNode{
					{Title: "Babur & Foundation of Mughal Rule", Level: "subtopic"},
					{Title: "Akbar — Administration & Policies", Level: "subtopic"},
					{Title: "Jahangir, Shah Jahan & Aurangzeb", Level: "subtopic"},
					{Title: "Mughal Art, Architecture & Culture", Level: "subtopic"},
					{Title: "Decline of the Mughal Empire", Level: "subtopic"},
				}},
				{Title: "Bhakti & Sufi Movements", Level: "topic", Children: []SyllabusNode{
					{Title: "Bhakti Saints (Kabir, Ramananda, Tulsidas)", Level: "subtopic"},
					{Title: "Sufi Orders (Chishti, Suhrawardi)", Level: "subtopic"},
					{Title: "Impact on Society & Culture", Level: "subtopic"},
				}},
				{Title: "Maratha Empire", Level: "topic", Children: []SyllabusNode{
					{Title: "Shivaji & Maratha Administration", Level: "subtopic"},
					{Title: "Peshwa Period & Third Battle of Panipat", Level: "subtopic"},
				}},
			}},
			{Title: "Modern History", Level: "chapter", Children: []SyllabusNode{
				{Title: "Advent of Europeans", Level: "topic", Children: []SyllabusNode{
					{Title: "Portuguese, Dutch, French & British", Level: "subtopic"},
					{Title: "Battle of Plassey & Buxar", Level: "subtopic"},
					{Title: "Dual Government in Bengal/Bihar", Level: "subtopic"},
				}},
				{Title: "British Administration & Policies", Level: "topic", Children: []SyllabusNode{
					{Title: "Revenue Systems (Permanent Settlement, Ryotwari, Mahalwari)", Level: "subtopic"},
					{Title: "Social & Educational Reforms", Level: "subtopic"},
					{Title: "Economic Drain of Wealth", Level: "subtopic"},
				}},
				{Title: "Revolt of 1857", Level: "topic", Children: []SyllabusNode{
					{Title: "Causes of the Revolt", Level: "subtopic"},
					{Title: "Role of Kunwar Singh (Bihar)", Level: "subtopic"},
					{Title: "Bihar in the 1857 Revolt", Level: "subtopic"},
					{Title: "Consequences & Government of India Act 1858", Level: "subtopic"},
				}},
				{Title: "Indian National Movement", Level: "topic", Children: []SyllabusNode{
					{Title: "Formation of INC & Moderates", Level: "subtopic"},
					{Title: "Extremist Movement & Partition of Bengal", Level: "subtopic"},
					{Title: "Gandhian Era & Mass Movements", Level: "subtopic"},
					{Title: "Champaran Satyagraha (1917)", Level: "subtopic"},
					{Title: "Non-Cooperation, Civil Disobedience, Quit India", Level: "subtopic"},
					{Title: "Role of Bihar in Freedom Struggle", Level: "subtopic"},
				}},
				{Title: "Post-Independence India", Level: "topic", Children: []SyllabusNode{
					{Title: "Integration of States", Level: "subtopic"},
					{Title: "Five Year Plans", Level: "subtopic"},
					{Title: "Formation of Bihar & Jharkhand Separation", Level: "subtopic"},
				}},
			}},
		},
	},

	// ─── 2. Geography ────────────────────────────────────────
	{
		Title: "Geography", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Physical Geography", Level: "chapter", Children: []SyllabusNode{
				{Title: "Interior of the Earth, Earthquakes & Volcanoes", Level: "topic"},
				{Title: "Climatology & Indian Monsoon System", Level: "topic"},
				{Title: "Plate Tectonics", Level: "topic"},
			}},
			{Title: "Indian Geography", Level: "chapter", Children: []SyllabusNode{
				{Title: "Physical Features (Himalayas, Plains, Plateau, Coastal)", Level: "topic"},
				{Title: "Drainage System (Himalayan & Peninsular Rivers)", Level: "topic"},
				{Title: "Natural Resources & Agriculture", Level: "topic"},
				{Title: "Population & Urbanization", Level: "topic"},
			}},
			{Title: "Geography of Bihar", Level: "chapter", Children: []SyllabusNode{
				{Title: "Physical Features, Climate & Soils", Level: "topic"},
				{Title: "Rivers (Ganga, Kosi, Gandak, Son) & Flood Management", Level: "topic"},
				{Title: "Agriculture & Major Crops", Level: "topic"},
				{Title: "Industries & Mineral Resources", Level: "topic"},
			}},
		},
	},

	// ─── 3. Indian Polity ────────────────────────────────────
	{
		Title: "Indian Polity", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Indian Constitution", Level: "chapter", Children: []SyllabusNode{
				{Title: "Constituent Assembly, Preamble & Sources", Level: "topic"},
				{Title: "Fundamental Rights (Part III)", Level: "topic"},
				{Title: "Directive Principles & Fundamental Duties", Level: "topic"},
				{Title: "Union Government (President, PM, Parliament, SC)", Level: "topic"},
				{Title: "State Government (Governor, CM, Legislature, HC)", Level: "topic"},
				{Title: "Local Self Government (73rd & 74th Amendments)", Level: "topic"},
			}},
			{Title: "Governance & Public Policy", Level: "chapter", Children: []SyllabusNode{
				{Title: "Constitutional & Statutory Bodies (EC, CAG, UPSC, BPSC)", Level: "topic"},
				{Title: "Important Constitutional Amendments", Level: "topic"},
			}},
		},
	},

	// ─── 4. Economy ──────────────────────────────────────────
	{
		Title: "Economy", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Indian Economy", Level: "chapter", Children: []SyllabusNode{
				{Title: "Economic Planning, NITI Aayog & LPG Reforms", Level: "topic"},
				{Title: "Agriculture, Green Revolution & Food Security", Level: "topic"},
				{Title: "Banking & Finance (RBI, SEBI, Financial Inclusion)", Level: "topic"},
				{Title: "Fiscal Policy, GST & Budget", Level: "topic"},
				{Title: "Poverty, Employment & MGNREGA", Level: "topic"},
				{Title: "International Trade (WTO, IMF, FDI)", Level: "topic"},
			}},
			{Title: "Bihar Economy", Level: "chapter", Children: []SyllabusNode{
				{Title: "GSDP, Growth Rate & Bihar Budget", Level: "topic"},
				{Title: "Saat Nischay & Industrial Policy", Level: "topic"},
			}},
		},
	},

	// ─── 5. General Science ──────────────────────────────────
	{
		Title: "General Science", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Physics", Level: "chapter", Children: []SyllabusNode{
				{Title: "Mechanics & Newton's Laws", Level: "topic"},
				{Title: "Heat & Thermodynamics", Level: "topic"},
				{Title: "Optics & Sound", Level: "topic"},
				{Title: "Electricity & Magnetism", Level: "topic"},
				{Title: "Nuclear Physics & Energy", Level: "topic"},
			}},
			{Title: "Chemistry", Level: "chapter", Children: []SyllabusNode{
				{Title: "Atomic Structure, Periodic Table & Chemical Bonding", Level: "topic"},
				{Title: "Acids, Bases & Salts", Level: "topic"},
				{Title: "Everyday Chemistry (Metals, Polymers, Soaps)", Level: "topic"},
			}},
			{Title: "Biology", Level: "chapter", Children: []SyllabusNode{
				{Title: "Human Body Systems", Level: "topic"},
				{Title: "Diseases, Nutrition & Vaccines", Level: "topic"},
				{Title: "Genetics, Evolution & Biotechnology", Level: "topic"},
				{Title: "Plant Biology (Photosynthesis, Hormones)", Level: "topic"},
			}},
		},
	},

	// ─── 6. Environment & Ecology ────────────────────────────
	{
		Title: "Environment & Ecology", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Ecosystems, Food Chains & Biogeochemical Cycles", Level: "chapter"},
			{Title: "Biodiversity, Hotspots & Wildlife Protection", Level: "chapter"},
			{Title: "Pollution, Climate Change & Paris Agreement", Level: "chapter"},
			{Title: "National Parks & Sanctuaries in Bihar", Level: "chapter"},
		},
	},

	// ─── 7. Current Affairs ──────────────────────────────────
	{
		Title: "Current Affairs", Level: "subject",
		Children: []SyllabusNode{
			{Title: "National (Government Schemes, Awards, Appointments, Sports)", Level: "chapter"},
			{Title: "International (Organizations, Foreign Relations, Summits)", Level: "chapter"},
			{Title: "Bihar (State Schemes, Awards, Development Projects)", Level: "chapter"},
		},
	},

	// ─── 8. Bihar Special ────────────────────────────────────
	{
		Title: "Bihar Special", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Bihar History (Magadha, Nalanda, Freedom Struggle)", Level: "chapter"},
			{Title: "Bihar Culture (Chhath, Madhubani, Folk Art)", Level: "chapter"},
			{Title: "Bihar Administration (Legislature, BPSC, Districts)", Level: "chapter"},
		},
	},
}

// ═══════════════════════════════════════════════════════════════════════════
// Complete BPSC Mains Syllabus — GS Papers I–IV
// ═══════════════════════════════════════════════════════════════════════════

var bpscMainsSyllabus = []SyllabusNode{
	{
		Title: "GS Paper I — Indian Heritage & Culture, History, Geography", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Indian Culture — Art Forms, Literature & Architecture", Level: "chapter"},
			{Title: "Ancient to Modern History", Level: "chapter"},
			{Title: "Freedom Struggle & National Movement", Level: "chapter"},
			{Title: "World & Indian Geography", Level: "chapter"},
			{Title: "Disasters & Disaster Management", Level: "chapter"},
		},
	},
	{
		Title: "GS Paper II — Governance, Polity, Constitution, Social Justice", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Indian Constitution — Features, Amendments, Key Provisions", Level: "chapter"},
			{Title: "Separation of Powers & Federalism", Level: "chapter"},
			{Title: "Welfare Schemes for Vulnerable Sections", Level: "chapter"},
			{Title: "Issues Related to Education, Health, Women & Children", Level: "chapter"},
			{Title: "India's Foreign Policy & International Relations", Level: "chapter"},
		},
	},
	{
		Title: "GS Paper III — Technology, Economic Development, Environment, Security", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Indian Economy — Growth, Development & Employment", Level: "chapter"},
			{Title: "Government Budgeting & Fiscal Policy", Level: "chapter"},
			{Title: "Agriculture, Food Processing & Infrastructure", Level: "chapter"},
			{Title: "Science & Technology (IT, Space, Biotech, IPR)", Level: "chapter"},
			{Title: "Environment & Disaster Management (Bihar-specific)", Level: "chapter"},
			{Title: "Internal Security & Cyber Security", Level: "chapter"},
		},
	},
	{
		Title: "GS Paper IV — Ethics, Integrity & Aptitude", Level: "subject",
		Children: []SyllabusNode{
			{Title: "Ethics & Human Interface", Level: "chapter"},
			{Title: "Contributions of Moral Thinkers (Indian & Western)", Level: "chapter"},
			{Title: "Emotional Intelligence", Level: "chapter"},
			{Title: "Public Service Values & Ethics in Governance", Level: "chapter"},
			{Title: "Probity, Transparency & Case Studies", Level: "chapter"},
		},
	},
}
