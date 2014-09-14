;; packages

(require 'package)
(package-initialize)

;; ... package archives

(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/") t)
(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/") t)
(add-to-list 'package-archives '("marmalade" . "http://marmalade-repo.org/packages/") t)
(add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/") t)

;; ... packages to install

(defvar kyle/packages '(ace-jump-mode
                        ack
                        anaconda-mode
                        ;ag
                        auto-complete
                        color
			color-theme
			company
			company-anaconda
                        ;diminish
                        ;elpy
                        evil
                        ;evil-indent-textobject
                        ;evil-leader
                        ;evil-matchit
                        ;evil-nerd-commenter
                        ;evil-paredit
                        ;evil-visualstar
                        ;exec-path-from-shell
                        ;fill-column-indicator
                        ;flx-ido
                        ;flycheck
                        ;git-gutter+
                        ;git-gutter-fringe+
                        ;guide-key
                        ;haskell-mode
                        ;ido-ubiquitous
                        ;ido-vertical-mode
                        jedi
                        ;magit
                        ;markdown-mode
                        ;molokai-theme
                        ;multiple-cursors
                        ;paredit
                        ;popwin
                        ;pretty-mode
                        ;projectile
                        ;puppet-mode
                        ;python
                        python-environment
                        ;rainbow-delimiters
                        ;smart-mode-line
                        ;smex
                        ;surround
                        undo-tree
                        ;vimrc-mode
                        ;yasnippet
                        ))

;; ... refresh package metadata

(when (not package-archive-contents)
  (package-refresh-contents))

;; ... install missing packages

(dolist (package kyle/packages)
  (unless (package-installed-p package)
    (package-install package)))

;;
;; global editor options
;;

(global-font-lock-mode 1)
(global-linum-mode 1)
(column-number-mode 1)
(line-number-mode 1)
(show-paren-mode 1)
(setq show-paren-style 'expression)

;(global-company-mode 1)
;(company-mode 1)
;(add-to-list 'company-backends 'company-anaconda)

;;
;; ace-jump
;;

(eval-after-load "ace-jump-mode" '(ace-jump-mode-enable-mark-sync))

;;
;; ack
;;

(defvar ack-history nil
  "History for the `ack' command.")

(defun ack (command-args)
  (interactive
   (let ((ack-command "ack --nogroup --with-filename --all "))
     (list (read-shell-command "Run ack (like this): "
                               ack-command
                               'ack-history))))
  (let ((compilation-disable-input t))
    (compilation-start (concat command-args " < " null-device)
                       'grep-mode)))

;;
;; company
;;

(add-hook 'python-mode-hook
  (lambda ()
    (set (make-local-variable 'company-backends) '(company-anaconda))))

(global-company-mode 1)

(require 'color)

;(let ((bg (face-attribute 'default :background)))
;  (custom-set-faces
;    `(company-tooltip ((t (:inherit default :background ,(color-lighten-name bg 2)))))
;    `(company-scrollbar-bg ((t (:background ,(color-lighten-name bg 10)))))
;    `(company-scrollbar-fg ((t (:background ,(color-lighten-name bg 5)))))
;    `(company-tooltip-selection ((t (:inherit font-lock-function-name-face))))
;    `(company-tooltip-common ((t (:inherit font-lock-constant-face))))))

(let ((bg (face-attribute 'default :background)))
  (custom-set-faces
    ;`(company-tooltip ((t (:inherit default :background ,(color-lighten-name bg 2)))))
    `(company-tooltip ((t (:inherit default :background ))))
    ;`(company-scrollbar-bg ((t (:background ,(color-lighten-name bg 10)))))
    ;`(company-scrollbar-fg ((t (:background ,(color-lighten-name bg 5)))))
    `(company-tooltip-selection ((t (:inherit font-lock-function-name-face))))
    `(company-tooltip-common ((t (:inherit font-lock-constant-face))))))

;;
;; elpy
;;

;(setq elpy-rpc-backend "jedi")

;;
;; evil
;;

(evil-mode 1)

;;
;; key bindings
;;

(define-key global-map (kbd "C-c SPC") 'ace-jump-mode)
(define-key global-map (kbd "C-x SPC") 'ace-jump-mode-pop-mark)
(define-key evil-normal-state-map (kbd "SPC") 'ace-jump-mode)

;(add-hook 'python-mode-hook 'jedi:setup)
;(setq jedi:complete-on-dot t)

