import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Conditions d'utilisation - Quantara",
  description: "Conditions générales d'utilisation de l'application Quantara",
};

export default function TermsOfServicePage() {
  return (
    <main className="min-h-screen bg-[#14172C] text-gray-300">
      <div className="max-w-3xl mx-auto px-6 py-16">
        <div className="text-center mb-12">
          <h1 className="text-3xl font-bold text-[#FFD700] mb-2">
            Conditions Générales d&apos;Utilisation
          </h1>
          <p className="text-gray-500 text-sm">
            Dernière mise à jour : Avril 2026
          </p>
        </div>

        <Section title="1. Acceptation des conditions">
          {`En téléchargeant, installant ou utilisant l'application Quantara, vous acceptez d'être lié par les présentes Conditions Générales d'Utilisation (CGU). Si vous n'acceptez pas ces conditions, veuillez ne pas utiliser l'application.

Quantara se réserve le droit de modifier ces CGU à tout moment. Les modifications prennent effet dès leur publication dans l'application.`}
        </Section>

        <Section title="2. Description du service">
          {`Quantara est une application d'analyse sportive basée sur l'intelligence artificielle. Elle fournit des prédictions et analyses pour le football, le basketball et le hockey sur glace.

Les prédictions sont fournies à titre informatif uniquement et ne constituent en aucun cas des conseils de paris ou d'investissement. Quantara ne garantit pas l'exactitude des prédictions.`}
        </Section>

        <Section title="3. Inscription et compte">
          {`• Vous devez fournir un numéro de téléphone valide pour créer un compte
• Vous êtes responsable de la confidentialité de votre mot de passe
• Un seul compte par personne est autorisé
• Vous devez avoir au moins 18 ans pour utiliser Quantara
• Toute information fournie doit être exacte et à jour`}
        </Section>

        <Section title="4. Période d'essai">
          {`Chaque nouvel utilisateur bénéficie d'une période d'essai gratuite donnant accès aux fonctionnalités VIP. Cette période d'essai est limitée à une seule fois par appareil.

Toute tentative de contournement de cette limitation (création de comptes multiples, manipulation de l'identifiant d'appareil, etc.) est strictement interdite et peut entraîner la suspension du compte.`}
        </Section>

        <Section title="5. Abonnements et paiements">
          {`• Les abonnements sont disponibles en formules Starter, Pro et VIP
• Les prix sont affichés dans la devise locale de l'utilisateur
• Les paiements s'effectuent via Mobile Money (PawaPay, Wave)
• Les abonnements se renouvellent automatiquement sauf annulation
• Aucun remboursement n'est accordé pour la période en cours
• Quantara se réserve le droit de modifier les tarifs avec préavis`}
        </Section>

        <Section title="6. Utilisation acceptable">
          {`Il est interdit de :

• Partager, redistribuer ou revendre les prédictions de Quantara
• Utiliser des robots ou scripts pour accéder au service
• Tenter de contourner les mesures de sécurité
• Utiliser le service à des fins illégales
• Créer plusieurs comptes pour abuser de la période d'essai
• Porter atteinte au fonctionnement de l'application`}
        </Section>

        <Section title="7. Propriété intellectuelle">
          {`Tous les contenus de Quantara (textes, graphiques, logos, algorithmes, prédictions, design) sont protégés par le droit de la propriété intellectuelle et appartiennent à Quantara.

Toute reproduction, modification ou distribution non autorisée est strictement interdite.`}
        </Section>

        <Section title="8. Limitation de responsabilité">
          {`Quantara fournit ses analyses à titre informatif. En aucun cas Quantara ne pourra être tenu responsable :

• Des pertes financières liées aux paris sportifs
• De l'inexactitude des prédictions
• Des interruptions de service
• Des dommages indirects résultant de l'utilisation du service

Le jeu comporte des risques. Jouez de manière responsable.`}
        </Section>

        <Section title="9. Suspension et résiliation">
          {`Quantara se réserve le droit de suspendre ou résilier votre compte en cas de violation des présentes CGU, sans préavis ni remboursement.

Vous pouvez à tout moment supprimer votre compte depuis les paramètres de l'application. La suppression est irréversible et entraîne la perte de toutes vos données.`}
        </Section>

        <Section title="10. Protection des données">
          {`Le traitement de vos données personnelles est régi par notre Politique de Confidentialité, accessible depuis l'application et sur notre site web.

En utilisant Quantara, vous consentez à la collecte et au traitement de vos données conformément à cette politique.`}
        </Section>

        <Section title="11. Droit applicable">
          {`Les présentes CGU sont régies par le droit en vigueur en Côte d'Ivoire. Tout litige sera soumis aux tribunaux compétents d'Abidjan.

Si une disposition des présentes CGU est jugée invalide, les autres dispositions restent en vigueur.`}
        </Section>

        <Section title="12. Contact">
          {`Pour toute question relative aux présentes CGU :

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
