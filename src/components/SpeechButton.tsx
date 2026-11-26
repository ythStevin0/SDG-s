'use client';

import { useState } from 'react';
import { Volume2, VolumeX } from 'lucide-react';

export function SpeechButton({ text }: { text: string }) {
  const [speaking, setSpeaking] = useState(false);

  const handleToggle = () => {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
      return;
    }
    if (speaking) {
      window.speechSynthesis.cancel();
      setSpeaking(false);
      return;
    }

    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'id-ID';
    utterance.rate = 0.95;
    utterance.onend = () => setSpeaking(false);
    utterance.onerror = () => setSpeaking(false);
    setSpeaking(true);
    window.speechSynthesis.speak(utterance);
  };

  return (
    <button
      type="button"
      onClick={handleToggle}
      className="inline-flex min-h-[44px] items-center gap-2 rounded-lg border border-emerald-700 bg-white px-3.5 py-2 text-sm font-semibold text-emerald-800 hover:bg-emerald-50"
    >
      {speaking ? <VolumeX className="h-4 w-4" /> : <Volume2 className="h-4 w-4" />}
      <span>{speaking ? 'Hentikan Suara' : 'Bacakan Rekomendasi'}</span>
    </button>
  );
}
