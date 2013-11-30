package com.github.ixlibs.macro.elastix.tests

import com.github.ixlibs.macro.elastix.ElasticStorable
import com.github.ixlibs.macro.elastix.Id
import java.util.Date

@ElasticStorable
class Product {
	@Id @Property String id
	
	@Property String name
	@Property String description
	
	@Property Date created
	@Property Date lastModified
	
	@Property String[] tags
	
}