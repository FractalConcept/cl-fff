(in-package html)

(html-to-file #P"/temp/test-h1.html"
	      (:html
	       (:head (:title "Test html<1>")) :crlf
	       (:body
		(:h1 (esc "Test html<1>")) :crlf
		:br
		(:p "The multiplication table")
		((:table :bgcolor "mediumseagreen")
		 ((:tr :bgcolor "lemonchiffon")((:th :width "20" :align "lightgreen") "x")
		  (dotimes (a 11)
		    (html ((:th :width "20" :align "right") (ffmt "~a" a)))))
		 (dotimes (b 11)
		   (html (:tr ((:td :width "20" :align "right" :bgcolor "lightgreen") (ffmt "~a" b))
			      (dotimes (a 11)
				(html ((:td :width "20" :align "right" :bgcolor "mediumaquamarine") (ffmt "~a" (* a b))))))))))))

(pprint (macroexpand 
	 '(:html
	   (:head (:title "Test html<1>")) :crlf
	   (:body
	    (:h1 (esc "Test html<1>")) :crlf
	    :br
	    (:p "The multiplication table")
	    ((:table :bgcolor "mediumseagreen")
	     ((:tr :bgcolor "lemonchiffon")((:th :width "20" :align "lightgreen") "x")
	      (dotimes (a 11)
		(html ((:th :width "20" :align "right") (ffmt "~a" a)))))
	     (dotimes (b 11)
	       (html (:tr ((:td :width "20" :align "right" :bgcolor "lightgreen") (ffmt "~a" b))
			  (dotimes (a 11)
			    (html ((:td :width "20" :align "right" :bgcolor "mediumaquamarine") (ffmt "~a" (* a b)))))))))))))

(pprint (macroexpand '(html (:tr ((:td :width "20" :align "right" :bgcolor "green") (ffmt "~a" b))
			     (dotimes (a 11)
			       (html ((:td :width "20" :align "right") (ffmt "~a" (* a b)))))))))

(defun cv-title (title)
  (html ((:div :style "'border:none;border-bottom:solid windowtext 0.5pt'")
	 (:p (:b title)))))

(defmacro cv-item (date &rest text)
  `(html (:p (:b ,date) " "  ,@text)))

(html-to-file #P"/temp/cv-marc.html"
	      (:html
	       (:head (:title "CV Marc")) :crlf
	       (:body
		((:font :face "arial")
		 (:div
		  (:p "Marc Battyani" :br "3, Avenue Saint Marc" :br "77850 HERICY")
		  (:p ((:a :href "'mailto:Marc_Battyani@wanadoo.fr'") "Marc_Battyani@wanadoo.fr") :br
		      "T�l�phone personnel: +33 (0)1 60 74 24 25" :br
		      "T�l�phone professionnel: +33 (0)1 60 39 53 40")
		  :br ) :crlf
		 (cv-title "EXPERIENCE PROFESSIONNELLE")
		 (cv-item "Depuis 2000:"
			  "Directeur de la recherche et du d�veloppement et g�rant de la soci�t� FRACTAL CONCEPT qui a repris les activit�s en �lectronique et informatique de la soci�t� CONTEXT FREE")
		 (cv-item "1989 - 2000:"
			  "Directeur de la recherche de CONTEXT FREE, g�rant jusqu'en 1998. Conception, d�veloppement et mise au point de technologies en informatique et instrumentation." :br
			  
			  (:ul (:li "Pilotage de robots et traitement de signaux ultrasonores pour l'industrie a�ronautique et spatiale.")
			       (:li "Compilateurs et Frameworks de g�n�ration de logiciels Win32. Utilis� par les soci�t�s du groupe Sage pour r�aliser une dizaine de logiciels (Ciel Paie, Gestion Commerciale, Ciel et Sage �tats financiers...) commercialis�s � plus de 150000 exemplaires.")
			       (:li "Cryptographie: Chiffrement des mesures de surveillance des centrales nucl�aires par l'Agence Internationale de l'Energie Atomique")
			       (:li "Reconstitution d'images tomographiques m�dicales. Utilis� par les scanners M�caserto et Siemens")
			       (:li "Moteurs de base de donn�es documentaires et s�mantiques. Utilis� par le CETIM, MCP,...")
			       (:li "R�alit� virtuelle et visualisation 3D pour la DGA")
			       (:li "...")
			       )
			  "PDG (1996-1997) de la soci�t� In�dit SA sp�cialis�e en g�n�ration automatique de catalogues.")
		 (cv-item "1988 - 1989:"
			  "Ing�nieur consultant en nouvelles technologies dans la soci�t� COROM. Audit technique pour des soci�t�s de capital risque.")
		 (cv-item "1987 - 1988:"
			  "Ing�nieur de recherche aux Laboratoires d'Electronique et de Physique appliqu�es, centre de recherche du groupe PHILIPS, dans la division architecture de syst�mes. Les recherches portaient sur des architectures destin�es au traitement d'images. D�p�t d'un brevet sur un arbitre de bus sp�cialis� pour CDi.")
		 (cv-title "FORMATION")
		 ((:p :align "center") (:i "Ing�nieur Sup�lec promotion 1986 section Instrumentation" :br
					   "Post dipl�me (DEA) en informatique th�orique � l'universit� de Montr�al"))
		 (cv-item "1986 - 1987:"
			  "Assistant, �tudiant visiteur post-dipl�me � l'universit� de MONTREAL (CANADA) en informatique th�orique (cryptographie, th�orie des langage, intelligence artificielle) dans le cadre des �changes inter-universitaire franco-qu�b�cois. Recherches et mise au point d'un compilateur de moteur d'inf�rences pour un syst�me expert destin� aux architectes paysagistes")
 		 (cv-item "1983 - 1986:"
	 		  "Ecole Sup�rieure d'Electricit� (SUPELEC). Sp�cialisation en instrumentation, m�trologie. Entr� 1<sup>er</sup> sur concours P'")
 		 (cv-item "1986:"
	 		  "Licence et ma�trise d'informatique th�orique � l'universit� PARIS XI ORSAY en parall�le
avec la 3<sup>i�me</sup> ann�e � SUPELEC. Mentions TB")
		 (cv-title "DIVERS")
		 (:p "Anglais couramment lu, �crit et parl�.")
		 (:p "Laur�at du concours g�n�ral 1981 en physique. Repr�sentation de la FRANCE aux 12<sup>i�mes</sup> olympiades internationales de physique en 1981 � Varna (Bulgarie).")
		 (:p "Nationalit� fran�aise, 37 ans. Mari�, trois enfants.")
 		 ))))

