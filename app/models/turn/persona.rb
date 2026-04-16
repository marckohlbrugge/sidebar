module Turn::Persona
  def self.all
    @all ||= [
      Turn::Persona::FactChecker,
      Turn::Persona::Context,
      Turn::Persona::Comedy,
      Turn::Persona::Troll
    ]
  end

  def self.by_key
    @by_key ||= all.index_by(&:key)
  end

  def self.find(key)
    by_key[key.to_s]
  end
end
