module PersonasHelper
  PERSONA_COLORS = {
    "blue"   => { bg: "bg-blue-100",   border: "border-blue-500",   ring: "ring-blue-500",   text: "text-blue-900",   wave: "text-blue-500" },
    "purple" => { bg: "bg-purple-100", border: "border-purple-500", ring: "ring-purple-500", text: "text-purple-900", wave: "text-purple-500" },
    "orange" => { bg: "bg-orange-100", border: "border-orange-500", ring: "ring-orange-500", text: "text-orange-900", wave: "text-orange-500" },
    "green"  => { bg: "bg-green-100",  border: "border-green-500",  ring: "ring-green-500",  text: "text-green-900",  wave: "text-green-500" },
    "gray"   => { bg: "bg-gray-100",   border: "border-gray-500",   ring: "ring-gray-500",   text: "text-gray-900",   wave: "text-gray-500" }
  }.freeze

  def persona_classes(persona, part)
    PERSONA_COLORS.fetch(persona&.color || "gray").fetch(part)
  end
end
