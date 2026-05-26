import { useEffect, useRef, useState } from "react";
import { Image, Link, Trash2, Upload, ExternalLink } from "lucide-react";
import { adminApi } from "../api/adminClient";
import { Card, SectionHeader, Button } from "./ui";

export default function AdvertisementTab() {
  const [ad, setAd] = useState(null);   // { image_url, link_url, enabled }
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [linkUrl, setLinkUrl] = useState("");
  const [preview, setPreview] = useState(null); // local file preview
  const [file, setFile] = useState(null);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const fileRef = useRef(null);

  useEffect(() => {
    adminApi.getAd()
      .then((data) => {
        setAd(data || null);
        setLinkUrl(data?.link_url || "");
      })
      .catch(() => setAd(null))
      .finally(() => setLoading(false));
  }, []);

  function onFileChange(e) {
    const f = e.target.files?.[0];
    if (!f) return;
    setFile(f);
    const reader = new FileReader();
    reader.onload = (ev) => setPreview(ev.target.result);
    reader.readAsDataURL(f);
  }

  async function handleSave() {
    setError(null); setSuccess(null);
    if (!linkUrl.trim()) { setError("Please enter a link URL."); return; }
    if (!file && !ad?.image_url) { setError("Please upload a poster image."); return; }
    setSaving(true);
    try {
      const saved = await adminApi.saveAd(linkUrl.trim(), file || undefined);
      setAd(saved);
      setFile(null);
      setPreview(null);
      setSuccess("Ad saved and is now live!");
    } catch (e) {
      setError(e.message || "Failed to save ad.");
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!window.confirm("Disable the current ad?")) return;
    setDeleting(true);
    try {
      await adminApi.deleteAd();
      setAd(null);
      setLinkUrl("");
      setPreview(null);
      setFile(null);
      setSuccess("Ad disabled.");
    } catch (e) {
      setError(e.message || "Failed to disable ad.");
    } finally {
      setDeleting(false);
    }
  }

  const currentImage = preview || ad?.image_url;

  if (loading) return <div className="text-slate-400 text-sm py-8">Loading…</div>;

  return (
    <div className="space-y-6 max-w-2xl">
      <SectionHeader
        title="Advertisement"
        subtitle="Upload a poster image and link. The ad popup appears once per session when users log in."
      />

      {error && (
        <div className="bg-red-500/10 border border-red-500/30 text-red-400 text-sm rounded-lg px-4 py-3">
          {error}
        </div>
      )}
      {success && (
        <div className="bg-green-500/10 border border-green-500/30 text-green-400 text-sm rounded-lg px-4 py-3">
          {success}
        </div>
      )}

      {/* Current status */}
      {ad?.image_url && (
        <Card className="p-4 flex items-center gap-3">
          <div className="w-2.5 h-2.5 rounded-full bg-green-400 shrink-0" />
          <span className="text-sm text-slate-300">Ad is currently <span className="text-green-400 font-semibold">live</span></span>
          <a
            href={ad.link_url}
            target="_blank"
            rel="noopener noreferrer"
            className="ml-auto flex items-center gap-1 text-xs text-slate-500 hover:text-pink-400 transition-colors"
          >
            <ExternalLink className="w-3 h-3" />
            {ad.link_url}
          </a>
        </Card>
      )}

      {/* Poster upload */}
      <Card className="p-5 space-y-4">
        <div className="flex items-center gap-2 mb-1">
          <Image className="w-4 h-4 text-pink-400" />
          <span className="text-sm font-semibold text-white">Poster Image</span>
        </div>

        {/* Preview */}
        {currentImage ? (
          <div className="relative rounded-xl overflow-hidden border border-slate-700 bg-slate-900">
            <img
              src={currentImage}
              alt="Ad poster preview"
              className="w-full max-h-72 object-contain"
            />
            <button
              onClick={() => { setFile(null); setPreview(null); if (fileRef.current) fileRef.current.value = ""; }}
              className="absolute top-2 right-2 bg-black/60 hover:bg-black/80 rounded-full p-1.5"
            >
              <Trash2 className="w-3.5 h-3.5 text-white" />
            </button>
          </div>
        ) : (
          <div
            onClick={() => fileRef.current?.click()}
            className="border-2 border-dashed border-slate-700 hover:border-pink-500/50 rounded-xl p-10 flex flex-col items-center gap-3 cursor-pointer transition-colors"
          >
            <div className="w-12 h-12 rounded-full bg-slate-800 flex items-center justify-center">
              <Upload className="w-5 h-5 text-slate-400" />
            </div>
            <div className="text-sm text-slate-400 text-center">
              Click to upload poster<br />
              <span className="text-xs text-slate-600">JPEG, PNG or WebP · max 5 MB</span>
            </div>
          </div>
        )}

        <input
          ref={fileRef}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          className="hidden"
          onChange={onFileChange}
        />

        {!currentImage && (
          <button
            onClick={() => fileRef.current?.click()}
            className="w-full py-2.5 rounded-lg border border-slate-700 hover:border-slate-600 text-sm text-slate-400 hover:text-white transition-colors flex items-center justify-center gap-2"
          >
            <Upload className="w-4 h-4" />
            Choose image
          </button>
        )}
      </Card>

      {/* Link URL */}
      <Card className="p-5 space-y-3">
        <div className="flex items-center gap-2 mb-1">
          <Link className="w-4 h-4 text-pink-400" />
          <span className="text-sm font-semibold text-white">Click-through URL</span>
        </div>
        <input
          type="url"
          value={linkUrl}
          onChange={(e) => setLinkUrl(e.target.value)}
          placeholder="https://example.com/offer"
          className="w-full bg-slate-900 border border-slate-700 focus:border-pink-500 rounded-lg px-3 py-2.5 text-sm text-white placeholder-slate-500 outline-none transition-colors"
        />
        <p className="text-xs text-slate-500">
          When users tap the poster they will be taken to this URL.
        </p>
      </Card>

      {/* Actions */}
      <div className="flex items-center gap-3">
        <button
          onClick={handleSave}
          disabled={saving}
          className="flex-1 py-2.5 rounded-lg bg-pink-600 hover:bg-pink-500 disabled:opacity-50 text-white text-sm font-semibold transition-colors flex items-center justify-center gap-2"
        >
          {saving ? "Saving…" : "Save & Publish Ad"}
        </button>
        {ad?.image_url && (
          <button
            onClick={handleDelete}
            disabled={deleting}
            className="py-2.5 px-4 rounded-lg border border-red-500/40 hover:border-red-500 text-red-400 hover:text-red-300 text-sm font-medium transition-colors flex items-center gap-2"
          >
            <Trash2 className="w-4 h-4" />
            {deleting ? "Disabling…" : "Disable Ad"}
          </button>
        )}
      </div>
    </div>
  );
}
