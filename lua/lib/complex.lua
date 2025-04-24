-- complex number class from https://www.lua.org/pil/15.1.html

complex = {}

function complex.new (r, i) return {r=r, i=i} end

-- defines a constant `i'
complex.i = complex.new(0, 1)

function complex.add (c1, c2)
  return complex.new(c1.r + c2.r, c1.i + c2.i)
end

function complex.sub (c1, c2)
  return complex.new(c1.r - c2.r, c1.i - c2.i)
end

function complex.mul (c1, c2)
  return complex.new(c1.r*c2.r - c1.i*c2.i,
					 c1.r*c2.i + c1.i*c2.r)
end

function complex.inv (c)
  local n = c.r^2 + c.i^2
  return complex.new(c.r/n, -c.i/n)
end

return complex
