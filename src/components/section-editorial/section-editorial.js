import * as React from "react"
import './section-editorial.scss'
import Highlight from "../highlight/highlight"
import Card from "../card/card"
import Kangaroo from "../kangaroo/kangaroo"

const SectionEditorial = ({
  title,
  components,
}) => {

  const SwitchComponents = {
    Highlight,
    Card,
    Kangaroo
  };
  return(
    <section className="section-editorial">
        {components.map((item,index) => {
          const Switcher = SwitchComponents[item.name]
          return(
            <Switcher key={"switcher-"+index} {...item}/>
          )
        })}
    </section>
  )
}

export default SectionEditorial