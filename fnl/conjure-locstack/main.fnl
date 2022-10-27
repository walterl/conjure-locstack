(module conjure-locstack.main
  {autoload {text conjure.text
             log conjure.log
             str conjure.aniseed.string
             nvim conjure.aniseed.nvim
             view conjure.aniseed.view
             server conjure.client.clojure.nrepl.server
             a conjure.aniseed.core
             nrepl conjure.remote.nrepl}})

(var debug? false)

(defn toggle-debug []
  (set debug? (not debug?))
  debug?)

(defn- dlog [s]
  (when debug?
    (log.append (if (a.string? s) [s] s))))

(defn- send-op-msg [op msg cb]
  (server.with-conn-and-ops-or-warn
    [op]
    (fn [conn ops]
      (server.send
        (if (a.get ops op) (a.merge {: op :session conn.session} msg))
        (fn [msg]
          (dlog (.. "; response: " (view.serialise msg)))
          (cb (when (not msg.status.no-info)
                (or (. msg :info) msg))))))
    {:else (fn [] (log.append ["; [LocStack] Something went wrong 😵"]))}))

(defn ns-sym-info [ns sym]
  "Not used, but potentially useful."
  (log.append [(.. "; Looking up symbol " ns "/" sym " 🔎...")])
  (send-op-msg
    :info
    {: ns : sym}
    (fn [msg]
      (when msg
        (let [{: ns : name : arglists-str : doc : file : line : column} msg]
          (log.append
            [(.. "; " ns "/" name " " arglists-str)
             (.. "; \"" doc "\"")
             (.. "; " file ":" (or line "?") (if column (.. ":" column) ""))]))))))

(defn ns-path [ns]
  "Not used, but potentially useful."
  (log.append [(.. "; Looking up path for ns " ns " 🔎...")])
  (send-op-msg
    :ns-path
    {: ns}
    (fn [msg]
      (log.append [(.. "; " (a.get msg :path "¯\\_(ツ)_/¯"))]))))

(defn- ns-path-loc [ns cb]
  "Get location (`:path` attribute) from :ns-path op."
  (send-op-msg
    :ns-path
    {: ns}
    (fn [msg]
      (cb (when msg (a.get msg :path))))))

(defn- ns-sym-loc [ns sym cb]
  "Get location (`:file` attribute) from :info op."
  (send-op-msg
    :info
    {: ns : sym}
    (fn [msg]
      (cb (a.get msg :file)))))

(defn- frame-loc [frame cb]
  "Lookup location for `frame` and call `cb` with it."
  (let [{:fn fn* : ns :type frame-type} frame]
    (if
      (= :java frame-type)
      (cb nil) ; will cause unselectable loclist item

      (and (= :clj frame-type) ns fn*)
      (ns-path-loc ns cb)
      ;; We don't need to lookup with ns-sym-loc, because :stacktrace already
      ;; tried that... or so I assume. I haven't seen a case where an :info op
      ;; returned location data that :stacktrace didn't have.
      ; (ns-sym-loc ns fn* (fn [loc] (if loc (cb loc) (ns-path-loc ns cb))))
      )))

(defn- frame=? [x y]
  "Crude frame quality test based on `:name` and `:line` keys."
  (let [id-keys [:name :line]]
    (and (not (a.nil? x))
         (not (a.nil? y))
         (= (a.get x :name) (a.get y :name))
         (= (a.get x :line) (a.get y :line)))))

(defn- nrepl->nvim-path [path]
  "From conjure.client.clojure.nrepl.action"
  (if
    (text.starts-with path "jar:file:")
    (string.gsub path "^jar:file:(.+)!/?(.+)$"
                 (fn [zip file]
                   (if (> (tonumber (string.sub nvim.g.loaded_zipPlugin 2)) 31)
                     (.. "zipfile://" zip "::" file)
                     (.. "zipfile:" zip "::" file))))

    (text.starts-with path "file:")
    (string.gsub path "^file:(.+)$"
                 (fn [file]
                   file))

    path))

(defn st-frames->loclist-items [frames]
  (icollect [_ frame (ipairs frames)]
    (let [{: file-url : ns : line : name} frame
          file-url (nrepl->nvim-path file-url)
          [name-ns name-var] (str.split name "/")
          name-var (-?> name (str.split "/") (a.second))
          ns (if (a.empty? ns) name-ns ns)]
      ;; From `:help setqflist-what`:
      ;; {:filename file-url
      ;;  :module ns
      ;;  :lnum line
      ;;  :text name}
      {:filename file-url :module ns :lnum line :text name})))

(defn stacktrace->loclist []
  "Queries nREPL for last stacktrace (`:stacktrace` op), and loads it into the
  current location list."
  (log.append ["; [LocStack] Loading last stracktrace... ⏳"])
  (send-op-msg
    :stacktrace
    nil
    (fn [msg]
      (var frames (a.get msg :stacktrace []))
      (var no-url-frames
        (icollect [_ st (ipairs frames)]
          (if (a.empty? (a.get st :file-url)) st)))

      (let [set-loclist
            (fn []
              (if (a.empty? no-url-frames)
                (let [items (st-frames->loclist-items frames)]
                  (dlog (.. "; loclist items: " (view.serialise items)))
                  (nvim.fn.setloclist 0 items :r)
                  (nvim.ex.lopen)
                  (log.append ["; [LocStack] Stacktrace loaded into location list ✔️"]))
                (dlog (.. "; Still waiting for info on " (a.count no-url-frames) " frames."))))]
        (each [_ frm (ipairs no-url-frames)]
          (frame-loc
            frm
            (fn [loc]
              (let [frm* (a.assoc frm :file-url loc)]
                (set frames (a.map #(if (frame=? frm $) frm* $) frames))
                (set no-url-frames (a.filter #(not (frame=? $ frm)) no-url-frames))
                (set-loclist)))))))))

(defn- ns->locitem [ns lnum full-sym cb]
  (send-op-msg
    :ns-path
    {: ns}
    (fn [msg]
      (let [path (a.get msg :path)]
        (cb
          (if path
            (do
              (dlog (.. "; got path for " ns ": " path))
              {:filename (nrepl->nvim-path path)
               :module ns
               :lnum lnum
               :text (.. "(" full-sym ")")})
            (do
              (dlog (.. "; no path for " full-sym " either. Giving up ¯\\_(ツ)_/¯."))
              {:filename nil
               :module ns
               :lnum lnum
               :text (.. "(" full-sym ")")})))))))

(defn- line->locitem [line cb]
  (let [[full-sym jfn filename lnum] (str.split line ",,,")
        [ns sym] (str.split full-sym "%$")]
    (if (a.nil? sym)
      (ns->locitem ns lnum full-sym cb)
      (send-op-msg
        :info
        {: ns : sym}
        (fn [msg]
          (if msg
            (let [{: ns : name : file : line : column} msg
                  item {:filename (nrepl->nvim-path file)
                        :module ns
                        :lnum line
                        :text (.. name " (" full-sym ")")}]
              (dlog (.. "; got info for " full-sym))
              (cb item))
            (ns->locitem ns lnum full-sym cb)))))))

(defn- escape [s]
  (-> s
      (nvim.fn.escape "\"")
      (string.gsub "\n" "\\n")))

(defn- serialize-frame-code [frames-str]
  (let [code (escape frames-str)]
    (a.str "(->> \"" code "\" (clojure.edn/read-string) (map #(clojure.string/join \",,,\" %)) (clojure.string/join \\newline))")))

(defn register-stacktrace->loclist [reg]
  (local reg (if (a.empty? reg) "\"" reg))
  (log.append [(.. "; [LocStack] Processing stack frames in register " reg "... ⏳")])
  (let [code (serialize-frame-code (nvim.fn.getreg reg))]
    (dlog (.. "; code: " code))
    (server.eval
      {:code code}
      (nrepl.with-all-msgs-fn
        (fn [msgs]
          (local res (-?> (a.first msgs)
                          (a.get :value)
                          (string.gsub "^\"" "")
                          (string.gsub "\"$" "")
                          (string.gsub "\\n" "\n")))
          (if res
            (do
              (dlog (.. "; res: " (view.serialise res)))
              (var lines (str.split res "\n"))
              (let [set-loclist
                    (fn []
                      (let [str-count (a.count (a.filter a.string? lines))]
                        (if (< 0 str-count)
                          (dlog (.. "; Still waiting for info on " str-count " lines."))
                          (do
                            (nvim.fn.setloclist 0 lines :r)
                            (nvim.ex.lopen)
                            (log.append [(.. "; [LocStack] Stacktrace from register " reg " loaded into location list ✔️")])))))]
                (each [_ line (ipairs lines)]
                  (line->locitem
                    line
                    (fn [item]
                      (set lines (a.map #(if (= line $) item $) lines))
                      (set-loclist lines))))))
            (log.append ["; [LocStack] Something went wrong 😵"
                         (.. "; [LocStack] Did you yank the _entire_ exception's :trace value (including the surrounding vector) into register " reg "?")
                         "(-> ex Throwable->map :trace)"])))))))

(defn init []
  (nvim.create_user_command
    :LocStack
    #(stacktrace->loclist)
    {:desc "Load last stacktrace into location list"})
  (nvim.create_user_command
    :LocStackReg
    #(register-stacktrace->loclist (. $ :args))
    {:nargs "?"
     :desc "Load stack trace from specified register (or \") into location list"}))
