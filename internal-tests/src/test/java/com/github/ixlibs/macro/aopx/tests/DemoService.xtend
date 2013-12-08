package com.github.ixlibs.macro.aopx.tests

import com.github.ixlibs.macro.aopx.Aspect
import com.github.ixlibs.macro.aopx.NotNull

@Aspect(types=#["logging", "validating"])
class DemoService {
	
	def void message(@NotNull String name) {
		println("Hello x "+name)
	}
	/* 
	def int increment(int x, @NotNull Integer value) {
		return x + value 
	}*/
	
	/*def void ize() {
		message("Valami " + increment(10, 3))
	}*/
}