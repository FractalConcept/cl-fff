(in-package meta)

(export '*country-language*)
(defvar *country-language* :en)

(export '*country*)
(defvar *country* :en)

(export 'translated-string)
(defclass translated-string ()
  ((english  :initarg :en  :accessor english)
   (french   :initarg :fr  :accessor french)
   (german   :initarg :de  :accessor german)
   (spanish  :initarg :sp  :accessor spanish)
   (italian  :initarg :it  :accessor italian)))

(defun translated-string-reader (stream subchar arg)
  (declare (ignore arg subchar))
  (let ((first-char (peek-char nil stream t nil t)))
    (cond ((char= first-char #\space)
	   (read-char stream)	  ; skip over whitespaceitalian
	   (translated-string-reader stream nil nil))
	  ((char= first-char #\() ;read a list
	   (list* 'make-instance ''meta:translated-string (read stream t nil t)))
	  (t
	   (error "Bad translated-string expression")))))

(set-dispatch-macro-character #\# #\L 'translated-string-reader)

(defun check-string (string)
  (and string (> (length string) 0) string))

(export 'translate)
(defmethod translate ((tr-string t) &key default (country-lang *country-language*))
  (or (check-string tr-string) (translate default) ""))

(defmethod translate ((tr-string string) &key default (country-lang *country-language*))
  (or (check-string tr-string) (translate default) ""))

(defmethod translate ((tr-string list) &key default (country-lang *country-language*))
  (if (null tr-string)
      (if (not default)
	  ""
	  (translate default))
      (or (getf tr-string country-lang)
	  (translate default)
	  (getf tr-string :en)
	  (second tr-string)
	  "")))

(defmethod translate ((tr-string translated-string) &key default (country-lang *country-language*))
  (let ((string (case country-lang
		  (:fr (french tr-string))
		  (:en (english tr-string))
		  (:de (german tr-string))
		  (:sp (spanish tr-string))
		  (:it (italian tr-string)))))
    (or (check-string string) (translate default)
	(check-string (english tr-string))(check-string (french tr-string)))))

(defun translated-name (obj)
  (translate (user-name obj)))

(defun translated-class-name (obj)
  (translate (user-name (class-of obj))))

(defvar *default-void-link-text*
  (make-instance 'translated-string
		 :en "not defined" :fr "non d�fini"))

(defun translated-void-link-text (slot)
  (let ((translation (translate (void-link-text slot))))
    (if translation
      translation
      (translate *default-void-link-text*))))

(defun translate-reader (stream subchar arg)
  (declare (ignore arg subchar))
  (let ((first-char (peek-char nil stream t nil t)))
    (cond ((char= first-char #\space)
	   (read-char stream)	  ; skip over whitespace
	   (translate-reader stream nil nil))
	  ((char= first-char #\") ;read one string
	   `(meta:translate ,(read stream t nil t)))
	  ((char= first-char #\() ;read a list
	   `(meta:translate ',(read stream t nil t)))
	  (t
	   (error "Translate expression starts with ~A only \" or ( are accepted" first-char)))))

(set-dispatch-macro-character #\# #\T #'translate-reader)

(defclass object-help ()
  ((english-tooltip :initarg :en   :accessor english-tooltip)
   (english-help    :initarg :en-h :accessor english-help)
   (french-tooltip  :initarg :fr   :accessor french-tooltip)
   (french-help     :initarg :fr-h :accessor french-help)
   (german-tooltip  :initarg :de   :accessor german-tooltip)
   (german-help     :initarg :de-h :accessor german-help)
   (spanish-tooltip :initarg :sp   :accessor spanish-tooltip)
   (spanish-help    :initarg :sp-h :accessor spanish-help)
   (italian-tooltip :initarg :it   :accessor italian-tooltip)
   (italian-help    :initarg :it-h :accessor italian-help)
   ))

(defmethod tooltip ((help t) &optional (country-lang *country-language*))
   "")

(defmethod tooltip ((help string) &optional (country-lang *country-language*))
   help)

(defmethod tooltip ((slot fc-slot-definition-mixin) &optional (country-lang *country-language*))
  (tooltip (object-help slot)))

(defmethod tooltip ((help object-help) &optional (country-lang *country-language*))
  (let ((string
	 (case country-lang
	   (:fr (french-tooltip help))
	   (:en (english-tooltip help))
	   (:de (german-tooltip help))
	   (:sp (spanish-tooltip help))
	   (:it (italian-tooltip help)))))
    (or (check-string string)(check-string (english-tooltip help))(check-string (french-tooltip help)))))

(defmethod help ((help t) &optional (country-lang *country-language*))
   "")

(defmethod help ((help string) &optional (country-lang *country-language*))
   help)

(defmethod help ((slot fc-slot-definition-mixin) &optional (country-lang *country-language*))
  (help (object-help slot)))

(defmethod help ((help object-help) &optional (country-lang *country-language*))
    (case country-lang
      (:fr (french-help help))
      (:en (english-help help))
      (:de (german-help help))
      (:sp (spanish-help help))
      (:it (italian-help help))))

(defclass fc-function ()
  ((name        :initarg :name :accessor name)
   (user-name   :initarg :user-name :accessor user-name)
   (visible        :type boolean :initarg :visible :initform nil :accessor visible)
   (visible-groups :initarg :visible-groups :initform nil :accessor visible-groups)
   (html-tag-attributes :initform nil :accessor html-tag-attributes :initarg :html-tag-attributes)
   (get-value-html-fn :initform nil :accessor get-value-html-fn :initarg :get-value-html-fn)
   (get-value-title :initform nil :accessor get-value-title :initarg :get-value-title)
   (get-value-text :initform nil :accessor get-value-text :initarg :get-value-text)
   (get-value-sql :initform nil :accessor get-value-sql :initarg :get-value-sql)
   (get-object-func :initform nil :accessor get-object-func :initarg :get-object-func)
   (disable-predicate :initarg :disable-predicate :initform nil :accessor disable-predicate)
   (disable-predicate-fn :initform nil :accessor disable-predicate-fn)
   (object-help :initarg :object-help :accessor object-help)))

(export 'short-description)
(defmethod short-description (obj)
  (format nil "~A" obj))

(defmethod short-description ((obj root-object))
  (format nil "~A ~A" (translated-class-name obj) (id obj)))

(defvar *undefined-short-desc*
  (make-instance 'translated-string
		 :en "(no description)" :fr "(pas de description)"))

(defmethod short-description :around ((obj root-object))
  (let ((desc (call-next-method)))
    (if (and (stringp desc) (> (length desc) 0))
      desc
      (translate *undefined-short-desc*))))

(export 'long-description)
(defmethod long-description (obj)
  (short-description obj))

(defmethod cl::print-object ((object root-object) stream)
  (format stream "<FC-Object ~A ~A>"
	      (class-name (class-of object))
	      (id object)))
#+nil (if *print-redably*
      (write-string (short-description object) stream)
      (format stream "<FC-Object ~A ~A>"
	      (class-name (class-of object))
	      (id object)))