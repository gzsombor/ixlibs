package com.github.ixlibs.macro.aopx.tests

import org.junit.Test

class AspectTest {
	

	@Test def void testLoggingAspect() {
		val d = new DemoService()
		d.message("world")
	}
}