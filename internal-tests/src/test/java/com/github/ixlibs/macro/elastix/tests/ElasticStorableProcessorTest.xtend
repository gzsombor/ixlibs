package com.github.ixlibs.macro.elastix.tests

import com.github.ixlibs.macro.elastix.ElasticSearchObjectModel
import java.util.ArrayList
import java.util.Date
import org.elasticsearch.action.index.IndexRequest
import org.elasticsearch.action.index.IndexRequestBuilder
import org.junit.Assert
import org.junit.Test

class ElasticStorableProcessorTest {

	@Test def void testProductSerialization() {
		val p = new Product()
		p.id = "myId"
		p.description = "ProductDescription"
		p.created = new Date(1000)
		p.tags = #{"big", "elastic"}

		val b = new IndexRequestBuilder(null)
		p.serialize(b)

		val request = b.request as IndexRequest
		Assert.assertEquals("myId", request.id)
		Assert.assertEquals(Product::ElasticType, request.type)
		val map = request.sourceAsMap
		Assert.assertEquals("ProductDescription", map.get("description"))
		Assert.assertTrue("has lastModified", map.containsKey("lastModified"))
		Assert.assertNull("has lastModified", map.get("lastModified"))

		Assert.assertTrue("has name", map.containsKey("name"))
		Assert.assertNull("has name", map.get("name"))

		Assert.assertEquals("created", 1000, map.get("created"))

		Assert.assertEquals("tags", new ArrayList(#{"big", "elastic"}), map.get("tags"))

		println("source: " + map)
	}


	@Test def void generatedConstants() {
		Assert.assertNotNull(Product::ElasticType)
		Assert.assertNotNull(Product::BUILDER)
	}
	
	@Test def void hasElasticSearchObjectModelInterface() {
		val p = new Product
		val ElasticSearchObjectModel es = p as ElasticSearchObjectModel
		Assert.assertNotNull(es)
	} 
	

}
