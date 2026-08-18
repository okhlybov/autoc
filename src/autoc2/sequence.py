from autoc2.collection import Collection


#
class Sequence(Collection):
  
  def __setup__(self):
    super().__setup__()
    
    range = self.range
    r = range.variable("r")
    
    with self.contains as f:
      f.external_code = f"""
        {r.definition};
        for({r} = {range.new(f.target)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if({self.element.equal(range.front_view(r), f.element)}) return 1;
        }}
        return 0;
      """

    state = self.hasher.state_t.variable("state")

    with self.hash as f:
      f.external_code = f"""
        size_t result;
        {r.definition};
        {state.definition};
        {self.hasher.create(state)};
        for({r} = {range.new(f.target)}; !{range.empty(r)}; {range.move_front(r)}) {{
          {self.hasher.update(state, self.element.hash(range.front_view(r)))};
        }}
        result = {self.hasher.hash(state)};
        {self.hasher.destroy(state)};
        return result;
      """