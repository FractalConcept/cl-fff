(in-package meta)

(defun instanciable-sub-classes (class)
  (when (symbolp class) (setf class (find-class class)))
  (unless (c2mop:class-finalized-p class) (c2mop:finalize-inheritance class))
  (let ((classes (mapcan 'instanciable-sub-classes
                         (c2mop:class-direct-subclasses class))))
    (if (and (instanciable class))
        (cons class classes)
        classes)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (let (#+lispworks
        (cl-user::*packages-for-warn-on-redefinition*
         (remove "KEYWORD" cl-user::*packages-for-warn-on-redefinition* :test #'equal)))
    (deftype date () 'integer)
    (deftype ip-address () 'string)
    (deftype universal-time () 'integer)
    (deftype time-of-day () 'integer)
    (deftype color () 'string)
    (deftype timestamp () 'integer)
    (deftype decimal () 'double-float)
    (deftype context-strings () 'cons)))

(defun find-slot-by-name (class slot-name)
  (find slot-name (c2mop:class-slots class) :key #'c2mop:slot-definition-name))

(defun ensure-slot-def (class slot)
  (if (symbolp slot)
      (find-slot-by-name class slot)
      slot))

(export 'fc-object-p)
(defun fc-object-p (obj)
  (typep obj 'root-object))

(export 'anonymous-object-p)
(defun anonymous-object-p (object)
  (zerop (id object)))

(export 'object-ref)
(defmethod object-ref (obj)
  (short-description obj))


#+nil(defun save-all-objects ()
  (let ((saved-objects 0))
    (maphash #'(lambda (key object)
                 (when (and (internal-data-object object)(modified object))
                   (incf saved-objects)
                   (save-object object)))
             *named-objects*)
    (when (/= saved-objects 0)
      (flush-all-stores))
    saved-objects))

