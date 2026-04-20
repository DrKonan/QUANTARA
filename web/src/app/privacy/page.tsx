import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Politique de Confidentialité - Quantara",
  description: "Politique de confidentialité de l'application Quantara",
};

export default function PrivacyPolicyPage() {
  return (
    <main className="min-h-screen bg-[#14172C] text-gray-300">
      <div className="max-w-3xl mx-auto px-6 py-16">
        <div className="text-center mb-12">
          <h1 className="text-3xl font-bold text-[#FFD700] mb-2">
            Politique de Confidentialité
          </h1>
          <p className="text-gray-500 text-sm">
            Dernière mise à jour : Avril 2026
          </p>
        </div>

        <Section title="1. Données collectées">
          {`Quantara collecte les données suivantes pour le fonctionnement du service :

• Numéro de téléphone (obligatoire pour l'inscription)
• Adresse email (optionnelle)
• Nom d'utilisateur
• Photo de profil (optionnelle)
• Données biométriques (empreinte / Face ID) — stockées localement uniquement
• Identifiant d'installation (pour la gestion de la période d'essai)
• Données d'utilisation anonymisées (Firebase Analytics)`}
        </Section>

        <Section title="2. Utilisation des données">
          {`Vos données sont utilisées pour :

• Créer et gérer votre compte utilisateur
• Fournir l'accès aux prédictions selon votre abonnement
• Personnaliser votre expérience (langue, devise, notifications)
• Améliorer nos algorithmes de prédiction
• Envoyer des notifications pertinentes (résultats, nouvelles prédictions)
• Prévenir les abus (période d'essai, comptes multiples)`}
        </Section>

        <Section title="3. Stockage et sécurité">
          {`• Les données sont hébergées sur Supabase (infrastructure cloud sécurisée)
• Les mots de passe sont chiffrés (bcrypt)
• Les données biométriques restent sur votre appareil (Keychain iOS / Keystore Android)
• L'identifiant d'installation est stocké dans le stockage sécurisé de l'appareil
• Les communications sont chiffrées via HTTPS/TLS`}
        </Section>

        <Section title="4. Services tiers">
          {`Quantara utilise les services tiers suivants :

• Supabase — Authentification et base de données
• Firebase — Analytics, Crashlytics, Cloud Messaging
• PawaPay / Wave — Traitement des paiements Mobile Money
• Google Fonts — Typographies

Ces services ont leurs propres politiques de confidentialité.`}
        </Section>

        <Section title="5. Notifications">
          {`Quantara envoie des notifications push pour :

• Nouvelles prédictions disponibles
• Résultats des matchs analysés
• Rappels d'abonnement
• Mises à jour importantes

Vous pouvez désactiver les notifications à tout moment depuis les paramètres de l'application ou de votre appareil. L'historique des notifications est conservé localement.`}
        </Section>

        <Section title="6. Vos droits">
          {`Conformément à la réglementation, vous disposez des droits suivants :

• Droit d'accès — Consultez vos données dans votre profil
• Droit de rectification — Modifiez vos informations dans « Modifier le profil »
• Droit de suppression — Supprimez votre compte depuis Profil > Supprimer mon compte
• Droit d'opposition — Désactivez les notifications et analytics

La suppression du compte est irréversible et entraîne l'effacement de toutes vos données personnelles.`}
        </Section>

        <Section title="7. Données de paiement">
          {`Quantara ne stocke aucune donnée de paiement sensible. Les transactions sont traitées directement par nos partenaires PawaPay et Wave.

Pays supportés : Côte d'Ivoire, Sénégal, Mali, Burkina Faso, Bénin, Togo, Niger, Guinée, Cameroun, Gabon, Congo, RD Congo.`}
        </Section>

        <Section title="8. Contact">
          {`Pour toute question concernant la protection de vos données :

📧 Email : support@quantara.app
📱 Application : Aide & Support > Nous contacter`}
        </Section>

        <div className="mt-16 pt-8 border-t border-gray-800 text-center text-gray-500 text-sm">
          © 2026 Quantara. Tous droits réservés.
        </div>
      </div>
    </main>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: string;
}) {
  return (
    <div className="mb-10">
      <h2 className="text-lg font-semibold text-[#FFD700] mb-3">{title}</h2>
      <p className="whitespace-pre-line text-sm leading-relaxed">{children}</p>
    </div>
  );
}
