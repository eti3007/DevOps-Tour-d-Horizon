# DevOps-Tour-d-Horizon
Mise à disposition des sources vu lors de la présentation du 16 octobre 2017

## Infra as code
Vous trouverez dans ce repo le fichier Json qui concerne le template ARM qui a été utilisé pour créer les ressources suivantes sur le portail Azure :
  - Plan App
  - Web App
  - Storage Account

## Automation runbook
Vous trouverez également dans ce repo le script Powershell qui ciblent les ressources d'après une balise personalisée et qui active le cryptage du Blob Storage ainsi que la création du NSG et l'association avec le sous réseau. Il y aura bien entendu le Json du template ARM du groupe de ressource cible.
