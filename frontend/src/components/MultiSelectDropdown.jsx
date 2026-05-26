import { useState, useRef, useEffect } from "react";
import { ChevronDown, X } from "lucide-react";

/**
 * MultiSelectDropdown - Ultra-modern multi-select with inline selection display
 * 
 * @param {string} label - Field label
 * @param {Array} options - Array of {value, label, emoji?} objects
 * @param {Array} selected - Array of currently selected values
 * @param {Function} onChange - Callback when selection changes
 * @param {string} placeholder - Placeholder text
 * @param {string} maxHeight - Max dropdown height (default: "320px")
 * @param {string} className - Additional CSS classes
 */
export default function MultiSelectDropdown({
  label,
  options = [],
  selected = [],
  onChange,
  placeholder = "Select options",
  maxHeight = "320px",
  className = "",
  maxVisibleChips = 4, // Maximum number of chips to show before "+X more"
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [focusedIndex, setFocusedIndex] = useState(-1);
  const dropdownRef = useRef(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(event) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    }

    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
      return () => document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [isOpen]);

  // Keyboard navigation
  useEffect(() => {
    function handleKeyDown(event) {
      if (!isOpen) return;

      switch (event.key) {
        case "Escape":
          setIsOpen(false);
          setFocusedIndex(-1);
          break;
        case "ArrowDown":
          event.preventDefault();
          setFocusedIndex((prev) => (prev < options.length - 1 ? prev + 1 : prev));
          break;
        case "ArrowUp":
          event.preventDefault();
          setFocusedIndex((prev) => (prev > 0 ? prev - 1 : 0));
          break;
        case "Enter":
          event.preventDefault();
          if (focusedIndex >= 0 && focusedIndex < options.length) {
            const option = options[focusedIndex];
            const value = typeof option === "string" ? option : option.value;
            toggleOption(value);
          }
          break;
        default:
          break;
      }
    }

    if (isOpen) {
      document.addEventListener("keydown", handleKeyDown);
      return () => document.removeEventListener("keydown", handleKeyDown);
    }
  }, [isOpen, focusedIndex, options]);

  // Toggle selection of an option
  const toggleOption = (value) => {
    if (selected.includes(value)) {
      onChange(selected.filter((v) => v !== value));
    } else {
      onChange([...selected, value]);
    }
  };

  // Get label for a value (without emoji)
  const getOptionLabel = (value) => {
    const option = options.find((opt) => opt.value === value || opt === value);
    if (!option) return value;
    return typeof option === "string" ? option : option.label;
  };

  // Remove a selected item
  const removeOption = (value) => {
    onChange(selected.filter((v) => v !== value));
  };

  // Calculate visible and hidden chips
  const visibleSelected = selected.slice(0, maxVisibleChips);
  const hiddenCount = selected.length - maxVisibleChips;

  return (
    <div className={`relative ${className}`} ref={dropdownRef}>
      {label && (
        <label className="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wide">
          {label}
        </label>
      )}

      {/* Dropdown trigger - shows chips inside with fixed height */}
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className="w-full min-h-[48px] flex items-center justify-between gap-2 px-4 py-2 border-2 border-gray-200 rounded-2xl bg-white text-sm hover:border-pink-400 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:border-pink-500 transition-all duration-200"
      >
        {/* Left side: chips or placeholder */}
        <div className="flex-1 flex items-center gap-1.5 overflow-hidden min-h-[32px]">
          {selected.length === 0 ? (
            <span className="text-gray-400">{placeholder}</span>
          ) : (
            <>
              {visibleSelected.map((value) => (
                <span
                  key={value}
                  className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-rose-50 text-rose-700 border border-rose-200 text-xs font-medium whitespace-nowrap flex-shrink-0"
                >
                  {getOptionLabel(value)}
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      removeOption(value);
                    }}
                    className="hover:bg-rose-200 rounded-full p-0.5 transition"
                  >
                    <X size={10} strokeWidth={2.5} />
                  </button>
                </span>
              ))}
              {hiddenCount > 0 && (
                <span className="inline-flex items-center px-2 py-0.5 rounded-full bg-gray-100 text-gray-600 text-xs font-medium whitespace-nowrap flex-shrink-0">
                  +{hiddenCount}
                </span>
              )}
            </>
          )}
        </div>
        
        {/* Right side: chevron icon */}
        <ChevronDown
          size={20}
          className={`text-gray-400 transition-transform duration-300 flex-shrink-0 ${isOpen ? "rotate-180" : ""}`}
        />
      </button>

      {/* Dropdown menu - modern card style with selections inside */}
      {isOpen && (
        <div
          className="absolute z-50 w-full mt-2 bg-white border border-gray-100 rounded-2xl shadow-2xl overflow-hidden"
          style={{ maxHeight }}
        >
          <div className="overflow-y-auto" style={{ maxHeight }}>
            {options.length === 0 ? (
              <div className="px-4 py-8 text-sm text-gray-400 text-center">
                No options available
              </div>
            ) : (
              <div className="p-2">
                {options.map((option, index) => {
                  const value = typeof option === "string" ? option : option.value;
                  const label = typeof option === "string" ? option : option.label;
                  const emoji = typeof option === "string" ? null : option.emoji;
                  const isSelected = selected.includes(value);
                  const isFocused = index === focusedIndex;

                  return (
                    <button
                      key={value}
                      type="button"
                      onClick={() => toggleOption(value)}
                      onMouseEnter={() => setFocusedIndex(index)}
                      className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-left transition-all duration-200 ${
                        isSelected
                          ? "bg-gradient-to-r from-pink-500 to-rose-500 text-white shadow-md transform scale-[1.02]"
                          : isFocused
                          ? "bg-gray-50"
                          : "hover:bg-gray-50"
                      }`}
                    >
                      {/* Modern native emoji rendering */}
                      {emoji && (
                        <span className="text-2xl leading-none" style={{ fontFamily: 'system-ui, -apple-system, "Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji"' }}>
                          {emoji}
                        </span>
                      )}
                      
                      {/* Label */}
                      <span className={`flex-1 text-sm ${isSelected ? "font-semibold" : "font-medium text-gray-700"}`}>
                        {label}
                      </span>

                      {/* Selected indicator - X button */}
                      {isSelected && (
                        <div className="flex-shrink-0 w-6 h-6 rounded-full bg-white/20 flex items-center justify-center">
                          <X size={14} strokeWidth={3} />
                        </div>
                      )}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
