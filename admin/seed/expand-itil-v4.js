/**
 * Content expansion: ITIL v4 course (id: "itil-v4").
 *
 * Adds 6 more flashcards + 6 more quiz questions to each of the 7 modules
 * (cards/questions 7-12, alongside the existing 1-6), roughly doubling the
 * course from ~84 to ~168 flashcard+quiz items, and updates each module's
 * display subtitle to match the new counts.
 *
 * CHECK BEFORE RUNNING: a live check on 2026-08-29 found this course
 * actually has 8 modules, not 7 — this script only touches module-1
 * through module-7 and will silently leave module 8 unexpanded. Confirm
 * the real module count/ids in Firestore before running, and add an
 * eighth block here if warranted.
 *
 * WHY THIS LIVES HERE, NOT IN lib/
 * ---------------------------------
 * docs/SECURITY.md flags lib/screens/seed_*.dart as content that should never
 * have shipped inside the Flutter client — seeding is an admin-only operation,
 * and firestore.rules restrict catalogue writes to accounts listed in
 * admins/{uid}. This script uses the Admin SDK (which bypasses rules
 * entirely, same as functions/entitlements.js) and is meant to be run once,
 * by hand, from a machine with Firebase credentials — never bundled into the
 * app.
 *
 * HOW TO RUN
 * ----------
 * 1. Authenticate: `firebase login` (interactive), then either:
 *      a) `gcloud auth application-default login`, or
 *      b) set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON key
 *         downloaded from Firebase Console -> Project Settings -> Service
 *         Accounts.
 * 2. From this directory: `npm install firebase-admin` (no package.json here
 *    on purpose — this is a one-off tool, not a deployed function).
 * 3. `node expand-itil-v4.js`
 *
 * This ADDS documents (card-7..12, q-7..12) alongside the existing 1-6; it
 * does not touch or delete anything. Safe to re-run — it will just overwrite
 * the same doc ids with the same content.
 */

const admin = require("firebase-admin");
admin.initializeApp({ credential: admin.credential.applicationDefault() });

const db = admin.firestore();

async function addFlashcards(courseId, moduleId, cards, startIndex) {
  const col = db
    .collection("courses").doc(courseId)
    .collection("modules").doc(moduleId)
    .collection("flashcards");
  for (let i = 0; i < cards.length; i++) {
    await col.doc(`card-${startIndex + i}`).set(cards[i]);
  }
}

async function addQuiz(courseId, moduleId, questions, startIndex) {
  const col = db
    .collection("courses").doc(courseId)
    .collection("modules").doc(moduleId)
    .collection("quiz");
  for (let i = 0; i < questions.length; i++) {
    await col.doc(`q-${startIndex + i}`).set(questions[i]);
  }
}

async function setSubtitle(courseId, moduleId, flashcardCount, quizCount) {
  await db
    .collection("courses").doc(courseId)
    .collection("modules").doc(moduleId)
    .set({ subtitle: `${flashcardCount} flashcards · ${quizCount} questions` }, { merge: true });
}

async function expandModule(moduleId, flashcards, quiz) {
  await addFlashcards("itil-v4", moduleId, flashcards, 7);
  await addQuiz("itil-v4", moduleId, quiz, 7);
  await setSubtitle("itil-v4", moduleId, 6 + flashcards.length, 6 + quiz.length);
  console.log(`itil-v4/${moduleId}: +${flashcards.length} flashcards, +${quiz.length} quiz questions`);
}

async function main() {
  // ── MODULE 1 — Introduction to ITIL V4 ──────────────────────────────────
  await expandModule("module-1",
    [
      { order: 7, question: "How has ITIL evolved since it was first introduced?", answer: "ITIL began in the late 1980s as a UK government initiative (ITIL V1) to standardise IT practices, followed by a process-focused ITIL V2 and a lifecycle-based ITIL V3 in 2007. ITIL V4, released in 2019, is the current version, built around the Service Value System and a more holistic, flexible approach.", example: "A company still running ITIL V3 processes can adopt ITIL V4 concepts incrementally rather than replacing everything at once." },
      { order: 8, question: "Why do organisations adopt frameworks like ITIL?", answer: "Frameworks like ITIL codify proven practice so organisations don't have to reinvent service management from scratch. Adopting one typically improves service consistency, reduces risk, aligns IT with business goals, and gives staff a shared vocabulary.", example: "Two companies merging can use ITIL as common ground to align previously incompatible IT support processes." },
      { order: 9, question: "What are the three types of service provider defined in ITIL V4?", answer: "Type I is an internal service provider embedded within a single business unit. Type II is a shared services unit serving multiple business units within the same organisation. Type III is an external service provider supplying services to other organisations.", example: "An in-house IT helpdesk is Type I; a group-wide shared IT department serving several subsidiaries is Type II; an outsourced managed service provider is Type III." },
      { order: 10, question: "What is the difference between an IT asset and an IT service?", answer: "An IT asset is a resource — hardware, software, or infrastructure — owned or controlled by the organisation. An IT service is what that asset enables: the functionality and value delivered to a consumer.", example: "A physical server is an asset; the hosted application it runs, delivering value to users, is the service." },
      { order: 11, question: "What does \"service management\" mean as an organisational capability?", answer: "Service management is a set of specialised organisational capabilities for enabling value for customers in the form of services. It is broader than any single service — it is the organisation's overall ability to plan, deliver, operate, and improve services.", example: "A company's service management capability includes its people's skills, its tooling, its processes, and its culture — not just the IT systems themselves." },
      { order: 12, question: "What resources does a service provider typically combine to deliver a service?", answer: "A service provider combines resources such as people, information, technology, partners, and defined processes to deliver a service. These resource types map directly onto the four dimensions of service management.", example: "Delivering a helpdesk service requires trained staff (people), a ticketing system (technology), documented procedures (processes), and knowledge articles (information)." },
    ],
    [
      { order: 7, question: "Which version of ITIL introduced the Service Value System?", options: ["ITIL V2", "ITIL V3", "ITIL V4", "There is no such concept"], correctIndex: 2, explanation: "The Service Value System was introduced in ITIL V4 as the model showing how all parts of an organisation work together to create value." },
      { order: 8, question: "What is one key benefit organisations gain from adopting a framework like ITIL?", options: ["Guaranteed profit increase", "A shared vocabulary and proven practices for managing services", "Elimination of all IT risk", "Reduced need for skilled staff"], correctIndex: 1, explanation: "Frameworks like ITIL provide proven practices and a common vocabulary, helping organisations manage services more consistently and align IT with business goals." },
      { order: 9, question: "An outsourced company that manages IT for several external clients is an example of which provider type?", options: ["Type I — internal", "Type II — shared services", "Type III — external", "There is no such classification"], correctIndex: 2, explanation: "A Type III provider delivers services to other organisations rather than internally." },
      { order: 10, question: "What best distinguishes an IT asset from an IT service?", options: ["There is no difference", "An asset is a resource; a service is the value/functionality it enables", "A service is always physical hardware", "An asset only exists in the cloud"], correctIndex: 1, explanation: "An asset is a resource the organisation owns; a service is the functionality and value that resource helps deliver to a consumer." },
      { order: 11, question: "Service management, as an organisational capability, refers to what?", options: ["A single software tool", "The set of specialised capabilities for enabling value through services", "Only the IT department's org chart", "A certification exam"], correctIndex: 1, explanation: "Service management is the organisation's overall capability — people, process, technology, and more — for enabling value through services." },
      { order: 12, question: "Which of these is NOT one of the resource types a service provider typically combines to deliver a service?", options: ["People", "Technology", "Partners", "Weather"], correctIndex: 3, explanation: "Service providers combine people, information, technology, partners, and processes — weather is not a service management resource." },
    ]
  );

  // ── MODULE 2 — Key Concepts of Service Management ───────────────────────
  await expandModule("module-2",
    [
      { order: 7, question: "What is \"cost\" in the context of ITIL V4 value?", answer: "Cost is the amount of money spent on a specific activity or resource. From the consumer's view, cost removed by the service is part of what creates value; cost imposed on the consumer (the price they pay) is what they weigh against the benefit received.", example: "A cloud backup service removes the cost of buying physical servers (value driver) while charging a monthly fee (imposed cost)." },
      { order: 8, question: "What is \"risk\" in the context of ITIL V4 value?", answer: "Risk is the possible effect of uncertainty on objectives — the chance that something could go wrong and cause loss or harm. Both provider and consumer carry risk in a service relationship, and managing it well is part of what warranty is meant to assure.", example: "A payments provider bears the risk of a fraud spike; the merchant using the service bears the risk of the provider going down during a sale." },
      { order: 9, question: "How do utility, warranty, cost, and risk combine to determine value?", answer: "Value is realised when a service's utility (what it does) and warranty (how well it performs) are adequate relative to the cost and risk the consumer takes on. A service can have great utility but still fail to deliver value if its cost or risk outweighs the benefit.", example: "A powerful analytics tool (high utility) delivers little value if it is so unreliable (poor warranty) that reports can't be trusted." },
      { order: 10, question: "What is meant by \"service provision\"?", answer: "Service provision is the set of activities performed by the provider to deliver a service: managing the provider's resources configured to deliver it, ensuring access for authorised consumers, fulfilling agreed requirements, and providing ongoing support.", example: "A hosting provider provisioning a website means configuring servers, granting the client dashboard access, and staffing support for outages." },
      { order: 11, question: "What is meant by \"service consumption\"?", answer: "Service consumption is the set of activities performed by the consumer: managing the consumer's own resources needed to use the service, using provider resources, requesting service actions when needed, and paying for the service where agreed.", example: "A business consuming a payroll service still has to manage its own HR data and staff who use the software correctly." },
      { order: 12, question: "Can value be reduced or destroyed rather than co-created?", answer: "Yes — ITIL V4 recognises \"value co-destruction,\" where value is reduced because either party fails to perform its role adequately. Poor provider delivery and poor consumer use of a service can both undermine value.", example: "A CRM system loses value if the provider ships buggy updates, but also if staff never enter accurate data into it." },
    ],
    [
      { order: 7, question: "What does \"cost\" mean in ITIL V4's model of value?", options: ["Only the price charged to the customer", "The amount of money spent on an activity or resource, from both provider and consumer sides", "A synonym for risk", "The number of staff assigned to a service"], correctIndex: 1, explanation: "Cost covers money spent by both provider and consumer — cost removed by the service, and cost imposed on the consumer as price." },
      { order: 8, question: "What is \"risk\" in the context of service value?", options: ["A type of service offering", "The possible effect of uncertainty on objectives", "A synonym for warranty", "Something only the provider needs to manage"], correctIndex: 1, explanation: "Risk is the possible effect of uncertainty on objectives, and it is shared between provider and consumer." },
      { order: 9, question: "A service with excellent features but frequent outages illustrates a shortfall in which area?", options: ["Utility", "Warranty", "Cost", "Partnership"], correctIndex: 1, explanation: "Warranty is about how well a service performs — availability, capacity, security, continuity. Frequent outages are a warranty failure even if utility (functionality) is strong." },
      { order: 10, question: "Which activities are part of \"service provision\"?", options: ["Only paying an invoice", "Managing provider resources, ensuring access, and providing ongoing support", "Only using the service day to day", "Writing the Product Backlog"], correctIndex: 1, explanation: "Service provision covers the provider-side activities of configuring resources, granting access, meeting requirements, and supporting the service." },
      { order: 11, question: "Which activities are part of \"service consumption\"?", options: ["Configuring the provider's servers", "Managing the consumer's own resources and requesting service actions", "Writing the provider's SLAs", "Hiring the provider's staff"], correctIndex: 1, explanation: "Service consumption is the consumer-side activity: managing their own resources, using the service, and requesting support when needed." },
      { order: 12, question: "What does \"value co-destruction\" describe?", options: ["A service being retired", "Value being reduced because either party fails to perform its role adequately", "A pricing model", "A type of guiding principle"], correctIndex: 1, explanation: "Value co-destruction happens when poor performance by the provider, the consumer, or both undermines the value that should have been created." },
    ]
  );

  // ── MODULE 3 — The Four Dimensions Model ─────────────────────────────────
  await expandModule("module-3",
    [
      { order: 7, question: "How do all four dimensions apply to a single real scenario?", answer: "Consider launching a self-service password reset tool: Organisations and People (staff need training on the new process), Information and Technology (the reset portal itself), Partners and Suppliers (a vendor if the tool is bought in), and Value Streams and Processes (the reset workflow end to end).", example: "Skipping the people dimension — no staff communication — is a common reason self-service tools go unused even when the technology works fine." },
      { order: 8, question: "What role does governance play across the four dimensions?", answer: "Governance, one of the five SVS components, provides the oversight that keeps the four dimensions balanced and aligned with organisational policy and strategy — it is the mechanism that stops one dimension (often technology) from being over-invested in at the expense of the others.", example: "A steering committee reviewing a new platform investment checks that staffing and supplier contracts (not just the software) are accounted for before approval." },
      { order: 9, question: "What does the Information and Technology dimension include beyond software and hardware?", answer: "Beyond systems and tools, this dimension covers the information and knowledge needed to manage services, and the relationships and permissions around that information — who can access what, and how data is governed.", example: "A hospital's Information and Technology dimension includes not just its systems but strict access controls over patient records." },
      { order: 10, question: "What is the difference between a supplier and a partner in the Partners and Suppliers dimension?", answer: "A supplier relationship is typically transactional — goods or services are purchased with a defined, limited scope. A partner relationship is closer and more collaborative, often involving shared risk, reward, and strategic alignment over the longer term.", example: "Buying laptops from a hardware vendor is a supplier relationship; co-developing a new product roadmap with a strategic cloud vendor is closer to a partnership." },
      { order: 11, question: "How do value streams differ from a single process?", answer: "A value stream is the end-to-end series of steps that create and deliver value, and it typically spans multiple practices and processes working together. A single process is one structured set of activities within that larger flow.", example: "The value stream for \"resolve a customer incident\" spans incident management, knowledge management, and possibly change enablement — not just one process." },
      { order: 12, question: "How do the four dimensions relate to the Service Value System as a whole?", answer: "The four dimensions are not a separate model from the SVS — they are the perspectives that must be considered while operating every part of the SVS, from guiding principles to the value chain to individual practices, to ensure a holistic, balanced approach.", example: "When designing a new practice, teams check it against all four dimensions rather than treating it as a purely technical decision." },
    ],
    [
      { order: 7, question: "Launching a self-service tool but forgetting to train staff on it neglects which dimension?", options: ["Information and Technology", "Organisations and People", "Partners and Suppliers", "Value Streams and Processes"], correctIndex: 1, explanation: "Training, roles, and culture fall under Organisations and People — a common failure point even when the technology itself works." },
      { order: 8, question: "What is the purpose of governance in relation to the four dimensions?", options: ["To eliminate the need for suppliers", "To keep the dimensions balanced and aligned with organisational strategy", "To replace the Service Value Chain", "To manage only the Technology dimension"], correctIndex: 1, explanation: "Governance provides oversight that prevents any one dimension, often technology, from being over-invested in at the expense of the others." },
      { order: 9, question: "Strict access controls over patient records at a hospital fall under which dimension?", options: ["Organisations and People", "Information and Technology", "Partners and Suppliers", "Value Streams and Processes"], correctIndex: 1, explanation: "Information governance, including data access and permissions, is part of the Information and Technology dimension." },
      { order: 10, question: "What typically distinguishes a \"partner\" relationship from a \"supplier\" relationship?", options: ["Partners are always cheaper", "Partner relationships are closer and more collaborative, often with shared risk and reward", "Suppliers only exist in ITIL V3", "There is no meaningful difference"], correctIndex: 1, explanation: "Supplier relationships are typically transactional; partner relationships are closer, longer-term, and collaborative." },
      { order: 11, question: "A value stream for resolving a customer incident typically spans:", options: ["Only the Incident Management process", "Multiple practices and processes working together end to end", "Only the Service Desk", "Only the Change Enablement practice"], correctIndex: 1, explanation: "Value streams are end-to-end and typically involve several practices, such as incident management, knowledge management, and sometimes change enablement." },
      { order: 12, question: "How do the four dimensions relate to the Service Value System?", options: ["They are unrelated models", "They are the perspectives that must be considered while operating every part of the SVS", "They replace the SVS entirely", "They only apply to the Service Value Chain"], correctIndex: 1, explanation: "The four dimensions are the lens through which every part of the SVS — principles, governance, the value chain, practices — should be considered." },
    ]
  );

  // ── MODULE 4 — The Service Value System ──────────────────────────────────
  await expandModule("module-4",
    [
      { order: 7, question: "What happens in the \"Plan\" activity of the Service Value Chain?", answer: "Plan ensures a shared understanding of the vision, current status, and improvement direction across the organisation. It covers strategic, tactical, and operational planning to make sure all products and services support overall organisational goals.", example: "Setting a yearly roadmap for which new services to build, informed by business strategy, happens in the Plan activity." },
      { order: 8, question: "What happens in the \"Improve\" activity of the Service Value Chain?", answer: "Improve ensures continual improvement of products, services, and practices across every value chain activity and the SVS as a whole. It is the activity most closely tied to the Continual Improvement practice and model.", example: "Reviewing quarterly incident data and updating the escalation process based on what's found is the Improve activity in action." },
      { order: 9, question: "What happens in the \"Engage\" activity of the Service Value Chain?", answer: "Engage provides a good understanding of stakeholder needs, transparency, and good relationships with all stakeholders — including customers, users, partners, and suppliers — across the whole service lifecycle.", example: "Gathering customer feedback after a release, or maintaining an ongoing relationship with a key supplier, both sit within Engage." },
      { order: 10, question: "What happens in the \"Design and Transition\" activity of the Service Value Chain?", answer: "Design and Transition ensures that products and services continually meet stakeholder expectations for quality, cost, and time to market, moving new or changed components into live use safely.", example: "Piloting a new mobile banking feature with a small user group before a full rollout is part of Design and Transition." },
      { order: 11, question: "What happens in the \"Obtain/Build\" activity of the Service Value Chain?", answer: "Obtain/Build ensures that service components are available when and where they are needed, and that they meet agreed specifications — whether built in-house, bought, or otherwise sourced.", example: "Procuring cloud infrastructure or writing new application code both fall under Obtain/Build." },
      { order: 12, question: "What happens in the \"Deliver and Support\" activity of the Service Value Chain?", answer: "Deliver and Support ensures services are delivered and supported according to agreed specifications and stakeholder expectations, covering the day-to-day running of live services.", example: "A service desk resolving an incident and restoring a user's access is Deliver and Support in action." },
    ],
    [
      { order: 7, question: "Setting a yearly roadmap aligned to business strategy is an example of which Service Value Chain activity?", options: ["Engage", "Plan", "Obtain/Build", "Deliver and Support"], correctIndex: 1, explanation: "Plan covers strategic, tactical, and operational planning to align products and services with organisational goals." },
      { order: 8, question: "Which activity is most closely tied to the Continual Improvement practice?", options: ["Engage", "Design and Transition", "Improve", "Obtain/Build"], correctIndex: 2, explanation: "The Improve activity drives continual improvement across every other value chain activity and the SVS as a whole." },
      { order: 9, question: "Maintaining transparency and good relationships with customers and suppliers is part of which activity?", options: ["Engage", "Plan", "Deliver and Support", "Obtain/Build"], correctIndex: 0, explanation: "Engage covers stakeholder understanding and relationships across the whole service lifecycle." },
      { order: 10, question: "Piloting a new feature with a small group before full rollout belongs to which activity?", options: ["Obtain/Build", "Design and Transition", "Improve", "Plan"], correctIndex: 1, explanation: "Design and Transition ensures new or changed services move into live use safely while meeting stakeholder expectations." },
      { order: 11, question: "Procuring cloud infrastructure or writing new application code falls under which activity?", options: ["Engage", "Deliver and Support", "Obtain/Build", "Plan"], correctIndex: 2, explanation: "Obtain/Build ensures service components are available and meet specifications, whether built or bought." },
      { order: 12, question: "A service desk resolving an incident is an example of which Service Value Chain activity?", options: ["Deliver and Support", "Design and Transition", "Plan", "Improve"], correctIndex: 0, explanation: "Deliver and Support covers the day-to-day running and support of live services, including incident resolution." },
    ]
  );

  // ── MODULE 5 — Guiding Principles ────────────────────────────────────────
  await expandModule("module-5",
    [
      { order: 7, question: "What does Collaborate and Promote Visibility mean?", answer: "Working together across boundaries — teams, departments, and even organisations — produces better results and greater buy-in than working in isolation. Making work, plans, and progress visible builds trust and helps decisions get made with accurate information.", example: "Sharing a public roadmap and open incident status page lets other teams and customers see progress without having to ask." },
      { order: 8, question: "What does Keep It Simple and Practical mean?", answer: "Use the minimum number of steps needed to accomplish an objective. Judge whether a process, service, or metric adds real value, and remove anything that exists only out of habit or unnecessary complexity.", example: "A five-step approval chain for a routine, low-risk change can often be reduced to one automated check without increasing risk." },
      { order: 9, question: "How might several guiding principles apply to one real decision?", answer: "Principles are meant to be applied together, not one at a time. A single decision, such as adopting a new tool, might require focusing on value (does it help the customer), starting where you are (can existing tools be reused), and keeping it simple (avoiding an overly complex rollout).", example: "Choosing a new ticketing system means weighing customer value, existing staff familiarity, and avoiding unnecessary customisation — several principles at once." },
      { order: 10, question: "Why are the guiding principles described as recommendations rather than rules?", answer: "ITIL V4 deliberately avoids being prescriptive. The guiding principles are meant to inform judgement in a given situation, not to be applied rigidly regardless of context — different organisations and situations may weigh them differently.", example: "Progress Iteratively with Feedback usually applies, but a genuine emergency fix may need to move faster with less iteration." },
      { order: 11, question: "How might Focus on Value apply to a technical architecture decision?", answer: "Even a purely technical choice, like which database to use, should ultimately trace back to customer or business value — performance, reliability, or cost — rather than being chosen for its own sake or out of familiarity alone.", example: "Choosing a more expensive but far more reliable database for a payments system is justified by the value of avoiding failed transactions." },
      { order: 12, question: "What is a common pitfall when applying Keep It Simple and Practical?", answer: "Using the principle as an excuse to skip genuinely necessary steps, such as security review or testing, rather than removing steps that add no real value. Simplicity should never come at the cost of essential safeguards.", example: "Skipping a security review to \"keep it simple\" on a change touching customer payment data misapplies the principle rather than following it." },
    ],
    [
      { order: 7, question: "What does Collaborate and Promote Visibility encourage?", options: ["Working in isolation for faster results", "Working across boundaries and making work and progress visible", "Hiding project status until it's finished", "Reducing communication between teams"], correctIndex: 1, explanation: "This principle encourages cross-boundary collaboration and transparency to build trust and support better decisions." },
      { order: 8, question: "What does Keep It Simple and Practical focus on?", options: ["Adding more approval steps for safety", "Using the minimum steps needed and removing unnecessary complexity", "Avoiding all documentation", "Making every process the same regardless of risk"], correctIndex: 1, explanation: "This principle is about judging whether steps add real value and removing complexity that doesn't." },
      { order: 9, question: "Why should multiple guiding principles usually be applied together?", options: ["Only one principle is ever relevant at a time", "Real decisions typically involve several considerations the principles each address", "It is required by the exam", "Principles conflict and only one can be chosen"], correctIndex: 1, explanation: "A single real-world decision often touches value, existing capability, and simplicity at once, so several principles typically apply together." },
      { order: 10, question: "Why are the ITIL guiding principles described as recommendations rather than strict rules?", options: ["Because ITIL V4 has no principles", "Because they are meant to inform judgement given context, not apply rigidly", "Because they only apply to large enterprises", "Because they were removed in the latest update"], correctIndex: 1, explanation: "The principles guide judgement and should be weighed based on the situation, not applied mechanically." },
      { order: 11, question: "A team chooses a more expensive but more reliable database for a payments system. Which principle best explains this?", options: ["Keep it simple and practical", "Optimise and automate", "Focus on value", "Start where you are"], correctIndex: 2, explanation: "Even technical choices should trace back to value — here, avoiding failed transactions justifies the extra cost." },
      { order: 12, question: "What is a common misapplication of Keep It Simple and Practical?", options: ["Removing genuinely unnecessary approval steps", "Skipping necessary safeguards like security review to save time", "Automating a repetitive manual task", "Documenting only what is useful"], correctIndex: 1, explanation: "The principle is misapplied when it's used to justify skipping essential steps rather than removing genuinely wasteful ones." },
    ]
  );

  // ── MODULE 6 — ITIL Practices Overview ───────────────────────────────────
  await expandModule("module-6",
    [
      { order: 7, question: "What is the Service Level Management practice?", answer: "Service Level Management sets clear, business-based targets for service performance so that service delivery can be properly assessed, monitored, and managed against agreed expectations — typically documented in Service Level Agreements (SLAs).", example: "An SLA promising 99.9% uptime for an e-commerce platform is maintained and reported on through Service Level Management." },
      { order: 8, question: "What is the Service Request Management practice?", answer: "Service Request Management supports the agreed quality of a service by handling pre-defined, user-initiated requests in an effective and user-friendly manner — distinct from incidents, which are unplanned disruptions.", example: "Requesting a new software licence or a password reset is a service request, not an incident, because nothing is broken." },
      { order: 9, question: "What is the Release Management practice?", answer: "Release Management makes new and changed services and features available for use, planning and managing the timing and packaging of releases to balance the need for change with stability and risk.", example: "Bundling several smaller feature updates into a single monthly release reduces disruption compared with releasing each one separately." },
      { order: 10, question: "What is the Deployment Management practice?", answer: "Deployment Management moves new or changed hardware, software, documentation, or any other component to live environments, and may also deploy components to other environments such as testing or staging.", example: "Rolling a new application build out to production servers overnight is handled by Deployment Management." },
      { order: 11, question: "What is the Monitoring and Event Management practice?", answer: "Monitoring and Event Management systematically observes services and components, and detects, categorises, and prioritises the significance of events — enabling early detection of problems before they impact users.", example: "An automated alert firing when disk usage crosses 90% lets a team act before a server actually runs out of space." },
      { order: 12, question: "What is the Knowledge Management practice?", answer: "Knowledge Management maintains and improves the effective, efficient use of information and knowledge across the organisation, making sure the right people have access to the right knowledge at the right time.", example: "A searchable internal wiki of past incident fixes lets a new support agent resolve a recurring issue without escalating it." },
    ],
    [
      { order: 7, question: "What does Service Level Management primarily set and monitor?", options: ["Software licence counts", "Business-based targets for service performance, such as in an SLA", "Team holiday schedules", "Change approval workflows"], correctIndex: 1, explanation: "Service Level Management sets and monitors performance targets, typically documented as Service Level Agreements." },
      { order: 8, question: "Requesting a new software licence is an example of which practice?", options: ["Incident Management", "Problem Management", "Service Request Management", "Change Enablement"], correctIndex: 2, explanation: "Service Request Management handles pre-defined, user-initiated requests — nothing is broken, so it isn't an incident." },
      { order: 9, question: "What is the main purpose of Release Management?", options: ["To fix broken services", "To plan and manage the timing and packaging of releases", "To manage supplier contracts", "To write knowledge base articles"], correctIndex: 1, explanation: "Release Management balances the need for change with stability by planning how and when releases go out." },
      { order: 10, question: "Rolling a new application build out to production servers is an example of which practice?", options: ["Deployment Management", "Service Level Management", "Knowledge Management", "Monitoring and Event Management"], correctIndex: 0, explanation: "Deployment Management moves components into live (or other) environments." },
      { order: 11, question: "An automated alert firing when disk usage crosses a threshold is an example of which practice?", options: ["Release Management", "Monitoring and Event Management", "Service Request Management", "Service Level Management"], correctIndex: 1, explanation: "Monitoring and Event Management detects and prioritises events, enabling early action before impact." },
      { order: 12, question: "What is the main goal of Knowledge Management?", options: ["To reduce the number of practices", "To ensure the right people have access to the right knowledge at the right time", "To manage supplier invoices", "To schedule releases"], correctIndex: 1, explanation: "Knowledge Management maintains and improves effective use of information and knowledge across the organisation." },
    ]
  );

  // ── MODULE 7 — Final Exam Prep ───────────────────────────────────────────
  await expandModule("module-7",
    [
      { order: 7, question: "What are the three types of change recognised in Change Enablement, and how do they differ?", answer: "Standard changes are low-risk, pre-authorised, and well-understood, so they don't need individual authorisation each time. Normal changes require assessment and authorisation based on their risk. Emergency changes must be implemented urgently, often with an expedited approval process.", example: "Resetting a user's password (standard), upgrading a core banking system (normal), and patching an actively exploited vulnerability (emergency) each follow a different path." },
      { order: 8, question: "What are the three categories of ITIL practices, with an example of each?", answer: "General Management practices apply broadly across any organisation, like Continual Improvement or Risk Management. Service Management practices are specific to service delivery, like Incident Management or Service Level Management. Technical Management practices are adapted from technology domains, like Deployment Management.", example: "Knowing which category a practice falls into helps on exam questions that describe a practice and ask you to classify it." },
      { order: 9, question: "What is a good general strategy for scenario-based exam questions?", answer: "Read the scenario twice before looking at the options, eliminate clearly wrong answers first, and watch for absolute words like \"always\" or \"never\" — ITIL concepts are rarely absolute, so options containing them are often distractors.", example: "An option stating a Sprint or Sprint Goal can \"never\" change is a strong candidate for being incorrect, since ITIL and Agile concepts favour flexibility over rigidity." },
      { order: 10, question: "What is the difference between an IT Asset and a Configuration Item (CI)?", answer: "An IT Asset is any valuable component that can contribute to service delivery. A Configuration Item (CI) is any component that needs to be managed to deliver a service and is specifically tracked in a Configuration Management Database (CMDB) — not every asset is formally tracked as a CI.", example: "A laptop is an asset; once it is registered in the CMDB with its owner, warranty, and installed software tracked, it is also a Configuration Item." },
      { order: 11, question: "How do the SVS, the four dimensions, and the guiding principles fit together as one model?", answer: "The Service Value System is the overall model for how the organisation creates value. The four dimensions are the perspectives that must be balanced while operating any part of the SVS. The guiding principles are the recommendations that inform judgement and decision-making throughout — all three work together, not separately.", example: "Designing a new practice means using the guiding principles to make decisions, considering all four dimensions, within the structure the SVS provides." },
      { order: 12, question: "What are some key ITIL V4 acronyms worth memorising before the exam?", answer: "SVS (Service Value System), ITSM (IT Service Management), PESTLE (the six external factors affecting the four dimensions), and CI (Configuration Item) all appear frequently and are easy to confuse with similar-sounding Agile or project management terms.", example: "Mixing up ITIL's CI (Configuration Item) with the Agile/DevOps term \"CI\" for Continuous Integration is a common source of exam confusion." },
    ],
    [
      { order: 7, question: "Which type of change requires individual risk assessment and authorisation before implementation?", options: ["Standard change", "Normal change", "Emergency change", "None of them"], correctIndex: 1, explanation: "Normal changes require assessment and authorisation based on their specific risk, unlike pre-authorised standard changes." },
      { order: 8, question: "Which category does Incident Management belong to?", options: ["General Management", "Service Management", "Technical Management", "It has no category"], correctIndex: 1, explanation: "Incident Management is a Service Management practice — specific to delivering and supporting services." },
      { order: 9, question: "When answering a scenario-based exam question, an option using the word \"always\" should generally be treated as:", options: ["Almost certainly correct", "Worth extra suspicion, since ITIL concepts are rarely absolute", "Irrelevant to the answer", "Automatically the longest option"], correctIndex: 1, explanation: "Absolute language is a common signal of an incorrect distractor, since ITIL guidance favours context and judgement over rigid rules." },
      { order: 10, question: "What distinguishes a Configuration Item (CI) from a general IT Asset?", options: ["A CI is always more expensive", "A CI is specifically tracked in a CMDB as needed to deliver a service", "There is no difference", "Only software can be a CI"], correctIndex: 1, explanation: "Not every asset is formally tracked; a CI is one that is specifically managed and recorded in a Configuration Management Database." },
      { order: 11, question: "How do the SVS, the four dimensions, and the guiding principles relate to each other?", options: ["They are unrelated and tested separately", "They work together: the SVS is the overall model, dimensions are perspectives to balance, principles guide decisions", "The guiding principles replaced the four dimensions in ITIL V4", "Only the SVS matters for the exam"], correctIndex: 1, explanation: "All three form one integrated model rather than three separate topics." },
      { order: 12, question: "In ITIL V4, what does the acronym CI stand for?", options: ["Continuous Integration", "Configuration Item", "Customer Interaction", "Change Instruction"], correctIndex: 1, explanation: "In ITIL, CI means Configuration Item — easy to confuse with the unrelated DevOps term Continuous Integration." },
    ]
  );

  console.log("Done — ITIL v4 expanded from ~84 to ~168 flashcard+quiz items across 7 modules.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
