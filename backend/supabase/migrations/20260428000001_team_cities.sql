-- ================================================================
-- Table team_cities : coordonnées GPS des équipes
-- Utilisée par predict-prematch pour calculer la distance de
-- déplacement (Haversine) et appliquer un malus xG à l'extérieur
-- pour les longs déplacements (> 1500 km, matchs européens).
--
-- Alimentation : manuelle ou via un script de population.
-- Les équipes sans entrée retournent travelDistanceKm = undefined,
-- ce qui est géré silencieusement par le scoring engine.
-- ================================================================

create table if not exists public.team_cities (
  team_id    integer primary key,
  team_name  text    not null,
  city       text    not null,
  latitude   float   not null,
  longitude  float   not null
);

comment on table public.team_cities is
  'Coordonnées GPS des stades / villes des équipes pour le calcul de distance de déplacement.';
