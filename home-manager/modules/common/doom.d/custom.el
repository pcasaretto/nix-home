;;; custom.el --- Description -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Paulo Casaretto
;;
;; Author: Paulo Casaretto <paulo.casaretto@heatseeker>
;; Maintainer: Paulo Casaretto <paulo.casaretto@heatseeker>
;; Created: August 18, 2025
;; Modified: August 18, 2025
;; Version: 0.0.1
;; Keywords: abbrev bib c calendar comm convenience data docs emulations extensions faces files frames games hardware help hypermedia i18n internal languages lisp local maint mail matching mouse multimedia news outlines processes terminals tex text tools unix vc wp
;; Homepage: https://github.com/paulo.casaretto/custom
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  Description
;;
;;; Code:

;;; -*- lexical-binding: t -*-
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(safe-local-variable-values
   '((lsp-disabled-clients quote (rubocop-ls)) (lsp-rubocop-use-bundler . true))))
(custom-set-faces)
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.

(provide 'custom)
;;; custom.el ends here
