(in-package #:meta-web)

(defvar *graph-file-prefix* (asdf:system-relative-pathname :meta-web "./web-resources/"))
(defvar *projects-source-directory-prefix* (asdf:system-source-directory :meta-web))

(defvar *current-class* nil)
(defvar *current-slot* nil)
(defvar *current-slot-attribute* nil)

(defvar *database-pool* nil)
(defvar *meta-store* nil)
(defvar *save-database* t)
(defvar *in-store-timer* nil)
(defvar *projects-list* nil)
(defvar *meta-store-timer* nil)

(defparameter *database-ip* "127.0.0.1")
(defparameter *database-name* "MetaFractal")
(defparameter *database-user* "lisp")
(defparameter *database-pwd* "")
(defparameter *database-save-period* 30)
(defparameter *mod-lisp-port* 3100)
(defparameter *local-port* 25140)

(defparameter *init-file*
  #+macosx #P"~/initfc.lisp"
  #+linux #P"~/initfc.lisp"
  #+win32 #P"s:/sources/svn/fractal/initfc.lisp")

(defparameter *web-directory* (asdf:system-relative-pathname :meta-web "./web-resources/"))

(defvar *create-store* nil)

(defparameter *hunchentoot-acceptor* nil)

(defun start-hunchentoot ()
  (setf *hunchentoot-acceptor* (make-instance 'hunchentoot:easy-acceptor :port *local-port*  :document-root (namestring *web-directory*) :message-log-destination nil :access-log-destination nil))
  (hunchentoot:start *hunchentoot-acceptor*))

(defun stop-hunchentoot ()
  (hunchentoot:stop *hunchentoot-acceptor*))

(defun create-mongo-store ()
  (meta::initialize-store *meta-store*))

;; mongo store
(defconstant +mongo-collection-name+ "fw-objects")

(defun clear-db ()
  (mapcar (lambda (x)
            (cl-mongo:db.delete +mongo-collection-name+ x))
          (cadr (cl-mongo:db.find +mongo-collection-name+ :all))))

(defun meta-store-timer-fn ()
  (unless *in-store-timer*
    (setf *in-store-timer* t)
    (unwind-protect
	 (when (and *meta-store* *save-database*)
	   (setf *save-database* nil)
	   (util:with-logged-errors (:ignore-errors nil) ; t
	     (meta::save-modified-objects *meta-store*))
	   (setf *save-database* t))
      (setf *in-store-timer* nil))))

(defun start-meta-store-timer ()
  (let ((timer (mp:make-timer 'meta-store-timer-fn)))
    (mp:schedule-timer-relative timer *database-save-period* *database-save-period*)))

(defun create-store (database-type)
  (meta::initialize-store *meta-store*)
  (when (eq database-type :postgres)
    (create-meta-classes *meta-store*)))

(defun start-apache () ;; apache
  (interface:sa *mod-lisp-port*))

(defun sql-project-list () ;; postgres
  (sort (mapcar #'(lambda (x)
                    (meta::load-object (first x) meta-web::*meta-store*))
                (meta::sql-query "select id from project"))
        #'string< :key #'name))

(defun move-store-to-ascii-store (ascii-store-path project)
  (meta::load-all-sub-objects project)
  (format t "preloaded ~d objects~%" meta::*nb-of-object-loaded*)
  (meta::clear-preloaded-objects)
  (let ((new-store (make-instance 'meta::ascii-store :file-directory ascii-store-path)))
    (meta::initialize-store new-store)
    (meta::move-objects-to-store meta-web::*meta-store* new-store)
    (meta::register-named-object new-store project "project")
    (meta::save-modified-objects new-store)
    new-store))

(defun start (&key (webserver :hunchentoot) (database :text-files) (first-start nil) (mongo-db-name "mydb")
                (mongo-db-collection-name +mongo-collection-name+) debug (init-file nil)
                ascii-store-path )
  (assert (and (member webserver '(:hunchentoot :apache))
               (member database '(:postgres :mongo-db :text-files :memory))))
  (setf interface:*web-server* webserver)
  (when debug
    (log:config debug))
  (when init-file
    (load init-file))

  ;; data stores
  (case database
    (:postgres
     (meta::init-psql)
     (setf *database-pool* (meta:psql-create-db-pool *database-ip* *database-name* *database-user* *database-pwd*))
     (setf *meta-store* (make-instance 'meta:psql-store :db-pool *database-pool*)))
    (:mongo-db
     (setf *meta-store* (make-instance 'meta:mongo-store :database-name mongo-db-name :collection-name mongo-db-collection-name)))
    (:text-files
     (setf *meta-store* (make-instance 'meta::ascii-store
                                       :file-directory (or ascii-store-path (asdf:system-relative-pathname :meta-web "./db-store/")))))
    (:memory
     (setf *meta-store* (make-instance 'meta::void-store))))
  (when first-start
    (create-store database))
  (unless meta::*memory-store*
    (setf meta::*memory-store* (make-instance 'meta::void-store)))
  (setf *app* (meta::load-or-create-named-object *meta-store* "meta-app" 'meta-app))
  ;;  (setf *app*  (meta::load-or-create-named-object meta::*memory-store* "meta-app" 'meta-app))
  (setf *meta-store-timer* (start-meta-store-timer))

  ;; web server
;  (interface:ws-start)
  (case webserver
    (:hunchentoot
     (setf (symbol-function 'interface::write-request)
           #'interface::write-hunchentoot-request) ;; FIXME hack
     (setf (symbol-function 'interface::write-header)
           #'interface::write-hunchentoot-header) ;; FIXME hack
     (start-hunchentoot))
    (:apache
     (start-apache))))

(defun stop (&optional (hunchentoot? t))
  (when hunchentoot?
    (stop-hunchentoot)))

(defclass identified-user ()
  ((clipboard :accessor clipboard :initform (make-instance 'interface::clipboard :store meta::*memory-store*))))
(defmethod interface::clipboard ((user identified-user))
  (clipboard user))

(defvar %unique-user% nil)
