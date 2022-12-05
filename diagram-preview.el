;;; diagram-preview.el -*- lexical-binding: t -*-

;; Copyright (C) 2022 Imran Khan.

;; Author: Imran Khan <contact@imrankhan.live>
;; URL: https://github.com/natrys/diagram-preview
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; diagram-preview-mode lets you see preview of popular text based
;; diagram creation tools like graphviz, plantuml and mermaid
;;
;; it uses kroki.io which provides a unified API for many
;; such tools, as well as a hosted instance providing free access.
;;
;;; Code:

(require 'url)

(defgroup diagram-preview ()
  "Show diagram preview for modes like graphviz, plantuml etc."
  :group 'convenience)

(defcustom diagram-preview-file "/tmp/preview-diagram.png"
  "File on disk where diagram is saved before being previewed"
  :type 'string
  :group 'diagram-preview)

(defcustom diagram-preview-instance-url "https://kroki.io"
  "The API endpoint for running kroki instance"
  :type 'string
  :group 'diagram-preview)

(defun diagram-preview--api-type ()
  (pcase major-mode
    ('mermaid-mode "mermaid")
    ('plantuml-mode "plantuml")
    ('graphviz-dot-mode "graphviz")
    (_ (throw 'error "unknown format"))))

(defun diagram-preview--api-endpoint ()
  (format "%s%s/"
          (file-name-as-directory diagram-preview-instance-url)
          (diagram-preview--api-type)))

(defun diagram-preview--reload-buffer ()
  (with-current-buffer (or (get-file-buffer diagram-preview-file)
                           (find-file-noselect diagram-preview-file))
    (unless (eq major-mode 'image-mode)
      (image-mode)
      (set-buffer-multibyte t))
    (revert-buffer t t t)
    (display-buffer (current-buffer))))

(defun diagram-preview-show ()
  "Show preview of diagram for graphviz, plantuml or mermaid.js"
  (interactive)
  (let ((url (diagram-preview--api-endpoint))
        (url-request-method "POST")
        (url-request-extra-headers '(("Content-Type" . "text/plain")))
        (url-mime-accept-string "image/png")
        (url-user-agent "Emacs")
        (url-request-data
         (encode-coding-string
          (buffer-substring-no-properties (point-min) (point-max))
          'utf-8)))
    (url-retrieve url (lambda (_)
                        (goto-char (point-min))
                        (while (not (looking-at "\n"))
                          (forward-line))
                        (let ((coding-system-for-write 'binary)
                              (write-region-annotate-functions nil)
                              (write-region-post-annotation-function nil))
                          (write-region
                           (+ 1 (point)) (point-max)
                           diagram-preview-file nil :silent))
                        (clear-image-cache diagram-preview-file)
                        (diagram-preview--reload-buffer)
                        (message nil)))))

;;;###autoload
(define-minor-mode diagram-preview-mode
  "Minor mode to show diagram preview for modes like graphviz, plantuml etc."
  :lighter " diagram "
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c C-p") #'diagram-preview-show)
            map))

(provide 'diagram-preview-mode)
