import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/settings/locale_cubit.dart';

/// Shared localization fallback for UI text added after the initial ARB
/// templates. Existing generated AppLocalizations remain authoritative for
/// their own keys; this dictionary covers role-specific and help views.
/// This maps *UI labels*, not user-supplied report text or database content.
const Map<String, String> _lithuanian = {
  "Contacts": "Kontaktai",
  "Help": "Pagalba",
  "About": "Apie programėlę",
  "Support": "Pagalba",
  "Support center": "Pagalbos centras",
  "Language": "Kalba",
  "English": "English",
  "Lietuvių": "Lietuvių",
  "Choose language": "Pasirinkite kalbą",
  "Copy": "Kopijuoti",
  "Copied to clipboard": "Nukopijuota į iškarpinę",
  "Contact details": "Kontaktiniai duomenys",
  "Accommodation services": "Apgyvendinimo paslaugos",
  "Dormitory contacts": "Bendrabučių kontaktai",
  "General accommodation enquiries": "Bendri apgyvendinimo klausimai",
  "Official accommodation information": "Oficiali informacija apie apgyvendinimą",
  "Copy email": "Kopijuoti el. paštą",
  "Copy website": "Kopijuoti svetainės adresą",
  "Official website": "Oficiali svetainė",
  "Help and frequently asked questions": "Pagalba ir dažniausiai užduodami klausimai",
  "How do I report a problem?": "Kaip pranešti apie gedimą?",
  "Open New Report, select a category, describe the issue and submit it.": "Atverkite „Naujas pranešimas“, pasirinkite kategoriją, aprašykite gedimą ir pateikite pranešimą.",
  "How can I follow my report?": "Kaip stebėti savo pranešimą?",
  "Open My Reports, then choose a report to see its current status and details.": "Atverkite „Mano pranešimai“ ir pasirinkite pranešimą, kad matytumėte jo būseną ir informaciją.",
  "Can I add a photo?": "Ar galiu pridėti nuotrauką?",
  "You can attach a photo when submitting a report or from its details when available.": "Galite pridėti nuotrauką pateikdami pranešimą arba jo informacijos lange, jei ši funkcija prieinama.",
  "How do I change my profile?": "Kaip pakeisti profilio informaciją?",
  "Open Profile and choose Edit personal information. Account roles cannot be changed there.": "Atverkite profilį ir pasirinkite „Redaguoti asmeninę informaciją“. Čia naudotojo vaidmens pakeisti negalima.",
  "How do I reset my password?": "Kaip atkurti slaptažodį?",
  "On the sign-in screen, select Forgot password and use the link sent to your email.": "Prisijungimo lange pasirinkite „Pamiršote slaptažodį?“ ir naudokite el. paštu gautą nuorodą.",
  "What do the statuses mean?": "Ką reiškia būsenos?",
  "New means the report was submitted; In progress means work has started; Resolved means the work is complete.": "„Naujas“ reiškia, kad pranešimas pateiktas; „Vykdomas“ – darbai pradėti; „Išspręstas“ – darbai baigti.",
  "About FixMate": "Apie FixMate",
  "Smart dorm maintenance": "Išmani bendrabučio priežiūra",
  "FixMate helps residents report dormitory maintenance issues and follow their progress.": "FixMate padeda bendrabučio gyventojams pranešti apie gedimus ir stebėti jų sprendimą.",
  "Residents": "Gyventojai",
  "Maintenance staff": "Techninės priežiūros darbuotojai",
  "Moderators": "Moderatoriai",
  "Administrators": "Administratoriai",
  "Residents submit reports and follow updates.": "Gyventojai teikia pranešimus ir stebi jų būseną.",
  "Maintenance staff claim assigned work and update progress.": "Techninės priežiūros darbuotojai perima užduotis ir atnaujina jų būseną.",
  "Moderators review new submissions.": "Moderatoriai peržiūri naujus pranešimus.",
  "Administrators oversee reports, people and categories.": "Administratoriai prižiūri pranešimus, naudotojus ir kategorijas.",
  "Version": "Versija",
  "Data privacy": "Duomenų privatumas",
  "Your account can only access information permitted by its role.": "Jūsų paskyra gali pasiekti tik informaciją, kuri leidžiama pagal jai suteiktą vaidmenį.",
  "Use this app for routine maintenance requests. For emergencies, contact the relevant emergency services.": "Ši programėlė skirta įprastiems priežiūros prašymams. Skubiais atvejais kreipkitės į atitinkamas skubios pagalbos tarnybas.",
  "Contact your dormitory administration for building-specific assistance.": "Dėl konkretaus bendrabučio pagalbos kreipkitės į jo administraciją.",
  "Kauno kolegija accommodation services": "Kauno kolegijos apgyvendinimo paslaugos",
  "The contact below is published by Kauno kolegija; FixMate is not its official support channel.": "Toliau pateiktas kontaktas skelbiamas Kauno kolegijos. FixMate nėra oficialus jos pagalbos kanalas.",
  "Open": "Atidaryti",
  "Close": "Uždaryti",
  "Back": "Atgal",
  "Cancel": "Atšaukti",
  "Save": "Išsaugoti",
  "Saving…": "Saugoma…",
  "Loading": "Įkeliama",
  "Refresh": "Atnaujinti",
  "Retry": "Bandyti dar kartą",
  "Sign in": "Prisijungti",
  "Sign out": "Atsijungti",
  "Signing out...": "Atsijungiama...",
  "Create resident account": "Sukurti gyventojo paskyrą",
  "Forgot password?": "Pamiršote slaptažodį?",
  "Welcome to FixMate": "Sveiki atvykę į FixMate",
  "SMART DORM MAINTENANCE": "IŠMANI BENDRABUČIO PRIEŽIŪRA",
  "Email": "El. paštas",
  "Email address": "El. pašto adresas",
  "Password": "Slaptažodis",
  "Confirm password": "Pakartokite slaptažodį",
  "New password": "Naujas slaptažodis",
  "Confirm new password": "Pakartokite naują slaptažodį",
  "Hide password": "Slėpti slaptažodį",
  "Show password": "Rodyti slaptažodį",
  "Enter your password": "Įveskite slaptažodį",
  "Enter a valid email address": "Įveskite galiojantį el. pašto adresą",
  "Sign in or create a resident account.": "Prisijunkite arba sukurkite gyventojo paskyrą.",
  "Authorized maintenance staff, moderators and administrators only.": "Tik įgaliotiems techninės priežiūros darbuotojams, moderatoriams ir administratoriams.",
  "Residents can view and submit maintenance reports after signing in.": "Prisijungę gyventojai gali peržiūrėti ir pateikti priežiūros pranešimus.",
  "Full name": "Vardas ir pavardė",
  "Register for FixMate": "Užsiregistruokite FixMate",
  "Back to sign in": "Grįžti į prisijungimą",
  "Reset password": "Atkurti slaptažodį",
  "Check your email": "Patikrinkite el. paštą",
  "Forgot your password?": "Pamiršote slaptažodį?",
  "Enter your account email to request a secure reset link.": "Įveskite paskyros el. pašto adresą, kad gautumėte saugią slaptažodžio atkūrimo nuorodą.",
  "Create new password": "Sukurti naują slaptažodį",
  "Choose a new password": "Pasirinkite naują slaptažodį",
  "Update password": "Pakeisti slaptažodį",
  "Send reset link": "Siųsti atkūrimo nuorodą",
  "Profile not available": "Profilis nepasiekiamas",
  "Account role not permitted in this workspace": "Šiai paskyrai prieiga prie šios darbo srities neleidžiama",
  "My profile": "Mano profilis",
  "Edit profile": "Redaguoti profilį",
  "Edit personal information": "Redaguoti asmeninę informaciją",
  "Change profile photo": "Keisti profilio nuotrauką",
  "Your account": "Jūsų paskyra",
  "Role": "Vaidmuo",
  "Building": "Pastatas",
  "Room number": "Kambario numeris",
  "Not set": "Nenurodyta",
  "Not available": "Nepasiekiama",
  "No building": "Pastatas nenurodytas",
  "No room": "Kambarys nenurodytas",
  "Profile updated successfully.": "Profilis sėkmingai atnaujintas.",
  "Profile photo updated.": "Profilio nuotrauka atnaujinta.",
  "Quick actions": "Greitieji veiksmai",
  "Review updates on your maintenance requests": "Peržiūrėkite savo priežiūros prašymų naujienas",
  "Resolved": "Išspręsta",
  "In progress": "Vykdoma",
  "New": "Naujas",
  "Overview": "Apžvalga",
  "All reports": "Visi pranešimai",
  "Assignments": "Paskyrimai",
  "People": "Naudotojai",
  "Categories": "Kategorijos",
  "Operations": "Darbo sritis",
  "Recent activity": "Naujausia veikla",
  "All statuses": "Visos būsenos",
  "Status": "Būsena",
  "Category": "Kategorija",
  "All categories": "Visos kategorijos",
  "Submitted": "Pateikta",
  "Any date": "Bet kuri data",
  "Last 7 days": "Paskutinės 7 dienos",
  "Last 30 days": "Paskutinės 30 dienų",
  "Clear filters": "Išvalyti filtrus",
  "Search reports": "Ieškoti pranešimų",
  "Title, description, location, category or ID": "Pavadinimas, aprašymas, vieta, kategorija arba ID",
  "Title, location, description or report ID": "Pavadinimas, vieta, aprašymas arba pranešimo ID",
  "No reports found for this view.": "Šiame rodinyje pranešimų nerasta.",
  "Assign employee": "Paskirti darbuotoją",
  "Assign to maintenance staff": "Paskirti techninės priežiūros darbuotojui",
  "Maintenance employee": "Techninės priežiūros darbuotojas",
  "Refresh reports": "Atnaujinti pranešimus",
  "Available to claim": "Laukiantys perėmimo",
  "My jobs": "Mano užduotys",
  "Available": "Laisvi",
  "Internal notes": "Vidinės pastabos",
  "Add an internal maintenance note": "Pridėti vidinę priežiūros pastabą",
  "No internal notes yet.": "Vidinių pastabų dar nėra.",
  "Refresh notes": "Atnaujinti pastabas",
  "Review report": "Peržiūrėti pranešimą",
  "Report review": "Pranešimų peržiūra",
  "Refresh reviews": "Atnaujinti peržiūras",
  "Awaiting review": "Laukia peržiūros",
  "Reviewed": "Peržiūrėti",
  "Review outcome": "Peržiūros rezultatas",
  "Valid": "Tinkamas",
  "Duplicate": "Dublikatas",
  "Inappropriate": "Netinkamas",
  "Save decision": "Išsaugoti sprendimą",
  "A rejection reason is required.": "Reikia nurodyti atmetimo priežastį.",
  "No reports in this review category.": "Šioje peržiūros kategorijoje pranešimų nėra.",
  "View private photo": "Peržiūrėti privačią nuotrauką",
  "Private report photo": "Privati pranešimo nuotrauka",
  "Maintenance categories": "Priežiūros kategorijos",
  "Choose which issues residents can report.": "Pasirinkite, apie kokius gedimus gyventojai gali pranešti.",
  "Add category": "Pridėti kategoriją",
  "Edit category": "Redaguoti kategoriją",
  "Category name": "Kategorijos pavadinimas",
  "Available for new reports": "Galima pasirinkti naujiems pranešimams",
  "Active": "Aktyvi",
  "Inactive": "Neaktyvi",
  "Deactivate category?": "Išjungti kategoriją?",
  "Deactivate": "Išjungti",
  "No categories found.": "Kategorijų nerasta.",
  "Photo": "Nuotrauka",
  "Report photos": "Pranešimo nuotraukos",
  "No photos attached yet.": "Nuotraukų dar nepridėta.",
  "Remove selected photo": "Pašalinti pasirinktą nuotrauką",
  "JPEG, PNG or WebP": "JPEG, PNG arba WebP",
};

String fmTr(BuildContext context, String english) {
  final locale = Localizations.maybeLocaleOf(context)?.languageCode;
  if (locale != 'lt') return english;
  return _lithuanian[english] ?? english;
}

class FixMateText extends StatelessWidget {
  const FixMateText(this.data, {super.key, this.style, this.textAlign,
    this.overflow, this.maxLines, this.softWrap, this.textDirection,
    this.strutStyle, this.textWidthBasis, this.textHeightBehavior});

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final TextDirection? textDirection;
  final StrutStyle? strutStyle;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  @override
  Widget build(BuildContext context) => Text(
    fmTr(context, data), style: style, textAlign: textAlign,
    overflow: overflow, maxLines: maxLines, softWrap: softWrap,
    textDirection: textDirection, strutStyle: strutStyle,
    textWidthBasis: textWidthBasis, textHeightBehavior: textHeightBehavior,
  );
}

/// Available from login and from every authenticated role, including staff,
/// moderator and administrator. Uses the existing app-wide LocaleCubit.
class FixMateLanguageButton extends StatelessWidget {
  const FixMateLanguageButton({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const Key('app_language_menu'),
    tooltip: fmTr(context, 'Choose language'),
    icon: const Icon(Icons.language_outlined),
    onSelected: (value) => context.read<LocaleCubit>()
        .setLocale(Locale(value)),
    itemBuilder: (context) => const [
      PopupMenuItem(value: 'en', child: Text('English')),
      PopupMenuItem(value: 'lt', child: Text('Lietuvių')),
    ],
  );
}
