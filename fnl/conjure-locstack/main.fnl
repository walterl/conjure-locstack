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
          (dlog "; response: " (view.serialise msg))
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

      (let [log-results
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
                (log-results)))))))))

(defn init []
  (nvim.create_user_command :LocStack #(stacktrace->loclist) {}))
