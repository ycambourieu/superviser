#!/bin/bash
#

################################### Informations sur le programme
NOM_PROGRAMME="superviser_telegram.sh"
DESCRIPTION="Supervision Script for Linux systems with Telegram Notifications"
AUTEUR="Yohan CAMBOURIEU"
DATE="01/11/2020"
VERSION="1.0.0"

################################### Configuration des variables

REP_PROGRAMME=$(dirname $0)
MAIL_ADMIN="your@mail.com"
HOSTNAME="`hostname -f`"
DATETIME=`date "+%Y-%m-%d %H:%M:%S"`
BODY_MAIL="$REP_PROGRAMME/body_mail.txt"
PREFIX="[YOUR-SRV-NAME]"
SENDTELEGRAMCMD="/root/scripts/send-telegram.sh"
SENDTELEGRAMOK="0"
SENDTELEGRAMWARN="1"
WAITBEFORESEND="0" # Temps d'attente en secondes avant l'envoi d'un message Telegram

################################### Fonctions d'affichage

Afficher () {
	echo "[+] $1"
}

AfficherWarn () {
	echo -e "	[\033[33mWARN\033[0m] - $1"
}

AfficherCrit () {
	echo -e "	[\033[31mERR\033[0m] - $1"
}

AfficherOk () {
	echo -e "	[\033[32mOK\033[0m] - $1"
}

AfficherQuestion () {
	echo -e "[\033[33mQUEST\033[0m] - $1"
}

AfficherUsage () {
            AfficherCrit "Usage: $NOM_PROGRAMME"
}

AfficherVersionProgramme () {
	echo "$NOM_PROGRAMME - Version $VERSION"
	echo "Ecrit par $AUTEUR le $DATE"
}

################################### Fonctions d'action

RechercheMaj () {
    COMPLEMENT=""

	# Check mises a jour
	apt-get update > /dev/null
	if [ `apt-get --just-print upgrade | grep -c -E "^Inst"` -gt "0" ]; then
	        COMPLEMENT=`apt-get --just-print -u upgrade | grep "^Inst " | awk '{print$2}'`
		AfficherWarn "Mise à jours en attente : $COMPLEMENT"
		ContenuMail "[MAJ] Mise à jours en attente : $COMPLEMENT"
		if [[ $SENDTELEGRAMWARN == "1" ]];then
			sleep $WAITBEFORESEND
			$SENDTELEGRAMCMD "$HOSTNAME - [MAJ] Mise à jours en attente : $COMPLEMENT"
		fi
	else
		if [[ $SENDTELEGRAMOK == "1" ]];then
			sleep $WAITBEFORESEND
			$SENDTELEGRAMCMD "$HOSTNAME - Pas de mise à jour en attente"	
		fi
		AfficherOk "Pas de mise à jour en attente"	
	fi
}

TestSmart () {
	COMPLEMENT="Inconnu"

	SMART=`/usr/sbin/smartctl -H /dev/sda1| grep "SMART Health Status:" | tr -s " " | cut -d ":" -f 2 | cut -d " " -f 2`


	if [[ ($SMART == "OK") || ($SMART == "PASSED") ]];then
		AfficherOk "Etat SMART OK"
		if [[ $SENDTELEGRAMOK == "1" ]];then
			sleep $WAITBEFORESEND
			$SENDTELEGRAMCMD "$HOSTNAME - Etat SMART OK"	
		fi
	else
		COMPLEMENT="$SMART"
		AfficherCrit "Erreur SMART : $SMART"
		ContenuMail "[SMART] ETAT CRITICAL : $SMART"
		if [[ $SENDTELEGRAMWARN == "1" ]];then
			sleep $WAITBEFORESEND
			$SENDTELEGRAMCMD "$HOSTNAME - [SMART] ETAT CRITICAL : $SMART"
		fi
	fi

}

AnalyseAntivirus () {
	COMPLEMENT=""
	DOSSIERS="/etc /root /bin /home /lib /opt /sbin /usr"
	QUARANTAINE="/tmp/quarantaine"
	LOG="/var/log/clamav/virus-tr.log"

	if [ ! -d $QUARANTAINE ]; then
		mkdir -p $QUARANTAINE &> /dev/null
	fi

	# Lancement de l'analyse antivirus
	clamscan -iro $DOSSIERS --max-scansize=250M --move=$QUARANTAINE > scan_result.txt

	# Récupération des résultats d'analyse
	NB_INFECTED=`cat scan_result.txt | grep Infected | cut -d ':' -f 2- | cut -d ' ' -f 2-`
	NB_SCANNED=`cat scan_result.txt | grep Scanned | cut -d ':' -f 2- | cut -d ' ' -f 2-`
	SCAN_TIME=`cat scan_result.txt | grep Time | cut -d '(' -f 2- | cut -d ')' -f 1`

	if [ $NB_INFECTED -gt 0 ];then
		COMPLEMENT="$NB_INFECTED fichiers infectes - Duree du scan : $SCAN_TIME"
		AfficherCrit "$COMPLEMENT"

		if [[ $SENDTELEGRAMWARN == "1" ]];then
			sleep $WAITBEFORESEND
			$SENDTELEGRAMCMD "$HOSTNAME - [SCANAV] $NB_INFECTED fichiers infectes - Duree du scan : $SCAN_TIME"
		fi
	else
		COMPLEMENT="Pas de menaces détectées. Duree du scan : $SCAN_TIME"
		AfficherOk "$COMPLEMENT"

		if [[ $SENDTELEGRAMOK == "1" ]];then
			sleep $WAITBEFORESEND
			$SENDTELEGRAMCMD "$HOSTNAME - Pas de menaces détectées. Duree du scan : $SCAN_TIME"	
		fi

	fi

	rm -f scan_result.txt
	}

VerificaitonEspaceDisque () {
	WARN="75"
	CRITICAL="85"
	COMPLEMENT=""
	TMPNAME="`mktemp`"

	df | tail -n +2 |tr -s " " | cut -d " " -f 5- > $TMPNAME

	while read PARTITION
	do
	        POURCENTAGEUTIL=`echo ${PARTITION} | cut -d '%' -f 1`
	        if [ $POURCENTAGEUTIL -gt $WARN ] && [ $POURCENTAGEUTIL -lt $CRITICAL ]; then
				COMPLEMENT="Espace disque faible $PARTITION." 
				AfficherWarn "$COMPLEMENT"
				ContenuMail "[DISK] $COMPLEMENT"

			if [[ $SENDTELEGRAMWARN == "1" ]];then
				sleep $WAITBEFORESEND
				$SENDTELEGRAMCMD "$HOSTNAME - [DISK] $COMPLEMENT"
			fi

	        elif [ $POURCENTAGEUTIL -gt $CRITICAL ]; then
	        	COMPLEMENT="Espace disque critique $PARTITION." 
	        	AfficherCrit "$COMPLEMENT"
	        	ContenuMail "[DISK] $COMPLEMENT"

				if [[ $SENDTELEGRAMWARN == "1" ]];then
					sleep $WAITBEFORESEND
					$SENDTELEGRAMCMD "$HOSTNAME - [DISK] $COMPLEMENT"
				fi
	        else
				if [[ $SENDTELEGRAMOK == "1" ]];then
					sleep $WAITBEFORESEND
					#$SENDTELEGRAMCMD "$HOSTNAME - Espace disque OK sur $PARTITION."	
				fi
	        	AfficherOk "Espace disque OK sur $PARTITION  "
	        fi
	done < $TMPNAME
}

VerificationRaid () {
        COMPLEMENT=""
        RAID=`/sbin/mdadm --detail /dev/md0 | grep State | head -n 1 | cut -d ":" -f 2- | cut -d " " -f 2-`
        COMPLEMENT=`cat /proc/mdstat | egrep ^md`

        if [ $RAID == "clean" ]; then
        	AfficherOk "Raid fonctionnel : $COMPLEMENT"
        elif [ $RAID == "active" ]; then
            AfficherOk "Raid fonctionnel : $COMPLEMENT"
        else
            AfficherCrit "Problème de RAID : $COMPLEMENT"
        fi
}


EnvoiMail () {
	NB_ALERTE=$(cat $BODY_MAIL | wc -l)

	if [ $NB_ALERTE -gt 1 ];then
		Afficher "Des notifications sont à envoyer à l'administrateur ($MAIL_ADMIN) :"
		mail -s "$PREFIX $HOSTNAME - $DATETIME" $MAIL_ADMIN < $BODY_MAIL
		if [ $? -ne 0 ];then
			AfficherCrit "Problème lors de l'envoi du mail à $MAIL_ADMIN"
		else
			AfficherOk "Rapport envoyé à $MAIL_ADMIN"
		fi
	else
		Afficher "Pas d'alerte, aucun mail ne sera envoyé"
	fi
}

ContenuMail () {
	echo $1 >> $BODY_MAIL
}


################################### Programme

echo "Rapport de supervision de $HOSTNAME - $DATETIME" > $BODY_MAIL
Afficher "Rapport de supervision de $HOSTNAME - $DATETIME"

Afficher "Recherche des mises à jour APT :"
RechercheMaj

#Afficher "Validation SMART du disque dur :"
TestSmart

Afficher "Vérification de l'espace disque :"
VerificaitonEspaceDisque

#Afficher "Vérification du RAID :"
#VerificationRaid

Afficher "Analyse antivirus du système :"
#AnalyseAntivirus

EnvoiMail

