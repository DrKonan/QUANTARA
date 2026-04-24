import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Supprimer mon compte - Nakora",
  description: "Demande de suppression de compte Nakora",
};

export default function DeleteAccountPage() {
  return (
    <main className="min-h-screen bg-[#14172C] text-gray-300 flex items-center justify-center px-4">
      <div className="max-w-lg w-full">
        {/* Header */}
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-900/30 border border-red-700/40 mb-4">
            <svg
              className="w-8 h-8 text-red-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={1.5}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M15 12H9m12 0A9 9 0 1 1 3 12a9 9 0 0 1 18 0ZM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Z"
              />
            </svg>
          </div>
          <h1 className="text-2xl font-bold text-white mb-2">
            Supprimer mon compte
          </h1>
          <p className="text-gray-400 text-sm">Nakora — Gestion du compte</p>
        </div>

        {/* Card */}
        <div className="bg-[#1a1e35] border border-white/10 rounded-2xl p-8 space-y-6">
          {/* Warning */}
          <div className="bg-red-900/20 border border-red-700/30 rounded-lg px-4 py-3 flex gap-3">
            <span className="text-red-400 flex-shrink-0 mt-0.5">⚠️</span>
            <p className="text-sm text-red-300">
              La suppression de votre compte est <strong>définitive et irréversible</strong>. 
              Toutes vos données seront effacées sous 30 jours.
            </p>
          </div>

          {/* What gets deleted */}
          <div>
            <h2 className="text-white font-semibold mb-3">
              Données supprimées
            </h2>
            <ul className="space-y-2 text-sm text-gray-400">
              {[
                "Votre profil et informations personnelles",
                "Votre historique de prédictions",
                "Vos abonnements actifs (sans remboursement)",
                "Vos préférences et paramètres",
                "Votre historique de paiements",
              ].map((item) => (
                <li key={item} className="flex items-start gap-2">
                  <span className="text-red-400 mt-0.5 flex-shrink-0">×</span>
                  {item}
                </li>
              ))}
            </ul>
          </div>

          <hr className="border-white/10" />

          {/* How to delete */}
          <div>
            <h2 className="text-white font-semibold mb-3">
              Comment supprimer votre compte
            </h2>
            <div className="space-y-4">
              {/* Option 1 - In app */}
              <div className="bg-[#1f2440]/80 rounded-lg p-4">
                <p className="text-[#FFD700] font-medium text-sm mb-1">
                  Option 1 — Depuis l&apos;application (recommandé)
                </p>
                <ol className="text-sm text-gray-400 space-y-1 list-decimal list-inside">
                  <li>Ouvrez l&apos;application Nakora</li>
                  <li>Allez dans <strong className="text-gray-300">Profil</strong></li>
                  <li>Appuyez sur <strong className="text-gray-300">Supprimer mon compte</strong></li>
                  <li>Confirmez en saisissant votre mot de passe</li>
                </ol>
              </div>

              {/* Option 2 - By email */}
              <div className="bg-[#1f2440]/80 rounded-lg p-4">
                <p className="text-[#FFD700] font-medium text-sm mb-1">
                  Option 2 — Par email
                </p>
                <p className="text-sm text-gray-400 mb-2">
                  Envoyez une demande de suppression à notre équipe support :
                </p>
                <a
                  href="mailto:support@nakora.app?subject=Demande%20de%20suppression%20de%20compte&body=Bonjour%2C%0A%0AJe%20souhaite%20supprimer%20d%C3%A9finitivement%20mon%20compte%20Nakora.%0A%0ANum%C3%A9ro%20de%20t%C3%A9l%C3%A9phone%20associ%C3%A9%20%3A%20%0A%0AMerci."
                  className="inline-flex items-center gap-2 text-[#FFD700] hover:text-yellow-300 text-sm font-medium transition-colors"
                >
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75" />
                  </svg>
                  support@nakora.app
                </a>
                <p className="text-xs text-gray-500 mt-2">
                  Objet : &quot;Demande de suppression de compte&quot; — précisez votre numéro de téléphone.
                </p>
              </div>
            </div>
          </div>

          <hr className="border-white/10" />

          {/* Delay notice */}
          <p className="text-xs text-gray-500 text-center">
            Les demandes sont traitées sous <strong className="text-gray-400">72 heures ouvrées</strong>.
            La suppression effective des données intervient dans un délai de <strong className="text-gray-400">30 jours</strong>.
          </p>
        </div>

        {/* Footer */}
        <p className="text-center text-xs text-gray-600 mt-6">
          © {new Date().getFullYear()} Nakora — Tous droits réservés
        </p>
      </div>
    </main>
  );
}
