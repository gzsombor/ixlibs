package com.github.ixlibs.macro.elastix;

import java.io.IOException;

import org.elasticsearch.action.index.IndexRequestBuilder;
import org.elasticsearch.common.xcontent.XContentBuilder;
import org.elasticsearch.search.SearchHit;

public interface ElasticSearchObjectModel {

    /**
     * load the values from the SearchHit object into the object model.
     * 
     * @param hit
     * @return itself
     */
    public ElasticSearchObjectModel deserialize(SearchHit hit);

    public void serialize(XContentBuilder builder) throws IOException;

    public void serialize(IndexRequestBuilder builder) throws IOException;

}
