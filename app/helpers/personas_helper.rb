module PersonasHelper
  PERSONA_COLORS = {
    "blue" => {
      bg:     "bg-blue-100 dark:bg-blue-950/60",
      border: "border-blue-500 dark:border-blue-400",
      ring:   "ring-blue-500 dark:ring-blue-400",
      text:   "text-blue-900 dark:text-blue-200",
      wave:   "text-blue-500 dark:text-blue-400"
    },
    "purple" => {
      bg:     "bg-purple-100 dark:bg-purple-950/60",
      border: "border-purple-500 dark:border-purple-400",
      ring:   "ring-purple-500 dark:ring-purple-400",
      text:   "text-purple-900 dark:text-purple-200",
      wave:   "text-purple-500 dark:text-purple-400"
    },
    "orange" => {
      bg:     "bg-orange-100 dark:bg-orange-950/60",
      border: "border-orange-500 dark:border-orange-400",
      ring:   "ring-orange-500 dark:ring-orange-400",
      text:   "text-orange-900 dark:text-orange-200",
      wave:   "text-orange-500 dark:text-orange-400"
    },
    "green" => {
      bg:     "bg-green-100 dark:bg-green-950/60",
      border: "border-green-500 dark:border-green-400",
      ring:   "ring-green-500 dark:ring-green-400",
      text:   "text-green-900 dark:text-green-200",
      wave:   "text-green-500 dark:text-green-400"
    },
    "gray" => {
      bg:     "bg-gray-100 dark:bg-gray-900",
      border: "border-gray-500 dark:border-gray-400",
      ring:   "ring-gray-500 dark:ring-gray-400",
      text:   "text-gray-900 dark:text-gray-200",
      wave:   "text-gray-500 dark:text-gray-400"
    }
  }.freeze

  def persona_classes(persona, part)
    PERSONA_COLORS.fetch(persona&.color || "gray").fetch(part)
  end
end
